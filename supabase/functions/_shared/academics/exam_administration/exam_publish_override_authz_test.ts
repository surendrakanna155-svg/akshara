// Gap-sweep wave 2 · step 2 (security hardening, owner-ratified) —
// exam-publish override permission.
//
// FINDING (verified before this wave): handlePublishExamResults
// (exam_administration_handlers.ts) is gated on "publishExamResults", and
// reads `requireApproval = body?.requireApproval !== false && body?.
// require_approval !== false`. When the caller sets requireApproval: false the
// ENTIRE `if (requireApproval) { ... }` approval/verify block is skipped — so
// ANY publishExamResults holder (superAdmin, schoolAdmin, principal,
// vicePrincipal, management — 20260628000000_exam_governance_authz.sql) could
// publish unverified marks straight to students/parents.
//
// FIX (this wave):
//   1. New migration 20260860000000_exam_publish_override_authz.sql registers
//      a dedicated `overridePublishApproval` permission, granted ONLY to the
//      SENIOR set (superAdmin/schoolAdmin/principal — NOT vicePrincipal/
//      management, since bypassing governance is MORE privileged than a
//      normal publish).
//   2. handlePublishExamResults now requires the caller to ALSO hold
//      overridePublishApproval when requireApproval is false; otherwise it
//      throws ExamPublishOverrideForbiddenError, mapped to 403
//      EXAM_PUBLISH_OVERRIDE_FORBIDDEN. The requireApproval===true path is
//      unchanged (still gated only on publishExamResults + the approval
//      lookup).
//   3. On a successful override publish, a DISTINCT audit event
//      ("examResultsPublishOverridden" / "exam.results.publish_override") is
//      emitted IN ADDITION to the normal resultsPublished audit — so an
//      override is always separately queryable/alertable from a normal
//      (approval-gated) publish.
//
// Proven DB-free here (same seam as qw4_exam_route_contract_test.ts / qa_x_033
// / qw4_exam_publish_audit_test.ts):
//   • ROUTE CONTRACT — a publishExamResults-only holder sending
//     requireApproval:false is denied 403 BEFORE any tenant-DB call; the same
//     holder ALSO given overridePublishApproval passes the check and reaches
//     the (unconfigured) tenant DB (503 = DB-free proxy for "would publish").
//   • The normal requireApproval:true (default / omitted) path is UNCHANGED —
//     a plain publishExamResults holder still reaches the DB (503), never a
//     403 from the new check.
//   • HANDLER WIRING (static-source) — the override permission check precedes
//     the tenant-DB publish call, and the override-audit block sits inside the
//     publish success path (after publishExamResults, alongside
//     resultsPublished), gated on `!requireApproval`.
//
// REMAINDER (infra-blocked, needs ERP_TENANT_DATABASE_URL / live RLS): the
// actually-PERSISTED override audit_events row after a real override publish
// needs a live Postgres — same remainder qw4_exam_publish_audit_test.ts
// documents for the normal publish audit.

import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../../config.ts";
import type { AccessTokenClaims } from "../../jwt.ts";
import { signAccessToken } from "../../jwt.ts";
import { routeExamAdministration } from "./exam_administration_router.ts";
import { EXAM_PUBLISH_OVERRIDE_PERMISSION } from "./exam_administration_handlers.ts";
import { ExamPublishOverrideForbiddenError } from "./exam_administration_repository.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "exam-user-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions: perms,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

async function call(
  method: string,
  path: string,
  perms: string[],
  body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  return routeExamAdministration(req, config, method, path);
}

// ---------------------------------------------------------------------------
// Source-of-truth constant
// ---------------------------------------------------------------------------

Deno.test("gap-sweep W2S2: the override permission slug is overridePublishApproval", () => {
  assertEquals(EXAM_PUBLISH_OVERRIDE_PERMISSION, "overridePublishApproval");
});

// ---------------------------------------------------------------------------
// Route contract — override path (requireApproval: false)
// ---------------------------------------------------------------------------

Deno.test("W2S2: publish with requireApproval:false is DENIED (403) without overridePublishApproval", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/publish",
    ["publishExamResults"],
    { requireApproval: false },
  );
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "EXAM_PUBLISH_OVERRIDE_FORBIDDEN");
});

Deno.test("W2S2: publish with require_approval:false (snake_case) is ALSO denied without the override permission", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/publish",
    ["publishExamResults"],
    { require_approval: false },
  );
  assertEquals(res?.status, 403);
  assertEquals((await res!.json()).error.code, "EXAM_PUBLISH_OVERRIDE_FORBIDDEN");
});

Deno.test("W2S2: publish with requireApproval:false PASSES the gate WITH overridePublishApproval (reaches DB → 503)", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/publish",
    ["publishExamResults", "overridePublishApproval"],
    { requireApproval: false },
  );
  // Permission check passed → reached the (unconfigured) tenant DB where the
  // publish + BOTH audit emits would run.
  assertEquals(res?.status, 503);
});

Deno.test("W2S2: overridePublishApproval ALONE (without publishExamResults) cannot even reach the route (403 at the outer gate)", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/publish",
    ["overridePublishApproval"],
    { requireApproval: false },
  );
  assertEquals(res?.status, 403);
  // Denied by the OUTER withAuth(... "publishExamResults" ...) gate, not the
  // inner override check — still FORBIDDEN either way, but prove the base
  // permission is still required.
  assertEquals((await res!.json()).error.code, "FORBIDDEN");
});

// ---------------------------------------------------------------------------
// Route contract — normal path (requireApproval left true / omitted) is
// UNCHANGED by this wave.
// ---------------------------------------------------------------------------

Deno.test("W2S2: publish with NO body (default requireApproval:true) is unaffected — reaches DB (503), not 403", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/publish",
    ["publishExamResults"],
    {},
  );
  assertEquals(res?.status, 503);
});

Deno.test("W2S2: publish with requireApproval:true explicit is unaffected — reaches DB (503)", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/publish",
    ["publishExamResults"],
    { requireApproval: true },
  );
  assertEquals(res?.status, 503);
});

Deno.test("W2S2: publish route still rejects an unauthenticated caller (401)", async () => {
  const req = new Request("https://x/academics/exams/exam-1/publish", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ requireApproval: false }),
  });
  const res = await routeExamAdministration(
    req,
    config,
    "POST",
    "/academics/exams/exam-1/publish",
  );
  assertEquals(res?.status, 401);
});

// ---------------------------------------------------------------------------
// Typed error + handler wiring (static-source, DB-free)
// ---------------------------------------------------------------------------

Deno.test("W2S2: ExamPublishOverrideForbiddenError is a distinct typed 403 signal", () => {
  const err = new ExamPublishOverrideForbiddenError();
  assertEquals(err.name, "ExamPublishOverrideForbiddenError");
  assertStringIncludes(err.message, "overridePublishApproval");
});

Deno.test("W2S2 (handler wiring): mapExamError maps ExamPublishOverrideForbiddenError to 403 EXAM_PUBLISH_OVERRIDE_FORBIDDEN", async () => {
  const src = await Deno.readTextFile(
    new URL("./exam_administration_handlers.ts", import.meta.url),
  );
  const idx = src.indexOf("error instanceof ExamPublishOverrideForbiddenError");
  if (idx < 0) throw new Error("expected ExamPublishOverrideForbiddenError to be mapped");
  const branch = src.slice(idx, idx + 160);
  assertStringIncludes(branch, "EXAM_PUBLISH_OVERRIDE_FORBIDDEN");
  assertStringIncludes(branch, "403");
});

Deno.test("W2S2 (handler wiring): the override permission check runs in the ELSE of requireApproval, BEFORE the tenant-DB publish call", async () => {
  const src = await Deno.readTextFile(
    new URL("./exam_administration_handlers.ts", import.meta.url),
  );
  assertStringIncludes(src, "EXAM_PUBLISH_OVERRIDE_PERMISSION");
  assertStringIncludes(src, "throw new ExamPublishOverrideForbiddenError()");

  const overrideCheck = src.indexOf("throw new ExamPublishOverrideForbiddenError()");
  const publish = src.indexOf("publishExamResults(db");
  if (overrideCheck < 0 || publish < 0 || overrideCheck > publish) {
    throw new Error(
      "expected the override permission check to precede the publish call",
    );
  }
});

Deno.test("W2S2 (handler wiring): the override audit is emitted on the success path, gated on !requireApproval, alongside resultsPublished", async () => {
  const src = await Deno.readTextFile(
    new URL("./exam_administration_handlers.ts", import.meta.url),
  );
  assertStringIncludes(src, "exam.results.publish_override");
  assertStringIncludes(src, "examResultsPublishOverridden");

  const normalAudit = src.indexOf("examAudit.resultsPublished(");
  const overrideAudit = src.indexOf("exam.results.publish_override");
  // lastIndexOf: notifyParentsOfResults appears twice — once in its own
  // function DEFINITION (well above the publish handler) and once in the
  // actual CALL site inside handlePublishExamResults, which is the one that
  // must follow both audits.
  const notify = src.lastIndexOf("notifyParentsOfResults(");
  if (normalAudit < 0 || overrideAudit < 0 || notify < 0) {
    throw new Error("expected both audits to precede the parent-notify call");
  }
  // Both audits fire on the publish success path, before notifying parents.
  if (!(normalAudit < overrideAudit && overrideAudit < notify)) {
    throw new Error(
      "expected the normal publish audit, then the override audit, both before notifyParentsOfResults",
    );
  }
});
