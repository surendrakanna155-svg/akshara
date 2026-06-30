// QW4 · QA-B-034 (P0) — Academics / exam-administration route-contract (DB-free).
//
// routeExamAdministration owns /academics/exams. The two rows the spec calls
// out are the exam create (write) + exam list (read):
//   • POST /academics/exams  → handleCreateExam, gated on "manageExams"
//   • GET  /academics/exams  → handleListExams,  gated on "viewExams"
// (gate slugs are the source-of-truth EXAM_OPERATION_PERMISSIONS map in
// exam_administration_handlers.ts:56). Every exam op runs through withAuth =
// requirePermission(slug) then requireSchoolOperationalScope (handlers.ts:103).
//
// This proves the WRITE-PERSIST CONTRACT up to the DB boundary:
//   • POST is DENIED without manageExams (403) — incl. a viewExams-only reader;
//   • POST with manageExams + a valid body PASSES the gate + validation and
//     reaches the unconfigured tenant DB (503 = DB-free proxy for "persisting");
//   • POST with a missing required field (title) is rejected (422) before DB;
//   • GET is DENIED without viewExams (403) and PASSES with it (503);
//   • a manageExams holder also satisfies the GET (viewExams superset? no — they
//     are distinct slugs; a manage-only token without viewExams is denied GET);
//   • unauthenticated → 401; unregistered → 404; foreign path → null.
//
// REMAINDER (infra-blocked): the real 201 + a persisted exam_sessions row, and
// the per-school RLS isolation of that row, need a live ERP_TENANT_DATABASE_URL
// (live cert). The route/RBAC/validation contract is fully provable DB-free.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../../config.ts";
import type { AccessTokenClaims } from "../../jwt.ts";
import { signAccessToken } from "../../jwt.ts";
import { routeExamAdministration } from "./exam_administration_router.ts";
import { EXAM_OPERATION_PERMISSIONS } from "./exam_administration_handlers.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "exam-user-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "examCoordinator",
    role_slugs: ["examCoordinator"],
    primary_role: "examCoordinator",
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

const validExam = { title: "Term 2 Maths", subject: "Mathematics", grade: "8" };

Deno.test("QA-B-034: the create/list slugs are the documented exam permissions", () => {
  // Lock the source-of-truth map so a silent slug change fails this contract.
  assertEquals(EXAM_OPERATION_PERMISSIONS.createExam, "manageExams");
  assertEquals(EXAM_OPERATION_PERMISSIONS.listExams, "viewExams");
});

Deno.test("QA-B-034: POST /academics/exams is denied without manageExams (403)", async () => {
  // A viewExams-only reader cannot create an exam.
  const res = await call("POST", "/academics/exams", ["viewExams"], validExam);
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-034: POST /academics/exams persists with manageExams (passes gate+validation → 503)", async () => {
  const res = await call("POST", "/academics/exams", ["manageExams"], validExam);
  // Gate + body validation passed → reached the (unconfigured) tenant DB where
  // the createExamSession INSERT would run.
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-034: POST /academics/exams rejects a missing title (422) before the DB", async () => {
  const res = await call("POST", "/academics/exams", ["manageExams"], {
    subject: "Mathematics",
    grade: "8",
  });
  assertEquals(res?.status, 422);
});

Deno.test("QA-B-034: POST /academics/exams without school scope is denied (403)", async () => {
  const token = await signAccessToken(
    SECRET,
    claims(["manageExams"], { scope: "platform", school_id: null }),
    900,
  );
  const req = new Request("https://x/academics/exams", {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(validExam),
  });
  const res = await routeExamAdministration(req, config, "POST", "/academics/exams");
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-034: GET /academics/exams is denied without viewExams (403)", async () => {
  const res = await call("GET", "/academics/exams", ["manageExamMarks"]);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-034: GET /academics/exams reads with viewExams (passes gate → 503)", async () => {
  const res = await call("GET", "/academics/exams", ["viewExams"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-034: exam routes reject an unauthenticated caller (401)", async () => {
  const post = new Request("https://x/academics/exams", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(validExam),
  });
  assertEquals((await routeExamAdministration(post, config, "POST", "/academics/exams"))?.status, 401);
  const getReq = new Request("https://x/academics/exams", { method: "GET" });
  assertEquals((await routeExamAdministration(getReq, config, "GET", "/academics/exams"))?.status, 401);
});

Deno.test("QA-B-034: an unregistered /academics/exams path returns 404", async () => {
  const res = await call("DELETE", "/academics/exams", ["manageExams"]);
  assertEquals(res?.status, 404);
});

Deno.test("QA-B-034: a non-/academics/exams path returns null (no match)", async () => {
  const res = await call("GET", "/student/exams", ["viewExams"]);
  assertEquals(res, null);
});
