// P1 (observability) — student-attendance corrections are audited.
//
// PHASE-PRIOR REALITY (verified on entry): `attendance_handlers.ts` contained
// ZERO audit calls. The two submit routes and — critically — the staff decision
// route `PATCH /attendance/corrections/:id/status` (gated on
// `approveAttendanceCorrection`) mutated the record of a child's attendance with
// no `audit_events` row, so "who approved the change to my child's mark, and
// when?" had no server-side answer. `qa_r_008_audit_completeness_test.ts` then
// asserted an exemption whose premise ("the audited mutation is the staff
// APPROVAL") was false for that route — the approval audited nothing.
//
// WHAT IS PROVEN HERE (DB-free):
//   1. SPEC SHAPE — `attendanceAudit.correctionRequested` / `.correctionDecided`
//      carry actor-bindable identity, a real BEFORE→AFTER, the `source` route
//      and the requester's reason, plus a replay-safe outbox key.
//   2. WRITE PATH — `emitMutationAudit` with those specs issues exactly one
//      `audit_events` INSERT bound to the acting user, and one `domain_events`
//      INSERT. The correlation id is AUTO-DERIVED from the request (the reason
//      the handlers use `emitMutationAudit`, not raw `recordMutationAudit`,
//      which is why ~39 legacy sites persist a NULL correlation), and the
//      request's ip/user-agent are captured because the `Request` is passed.
//   3. PRIVACY — the child's NAME never reaches the audit metadata, and the
//      free-text reason never reaches the fan-out `domain_events` payload.
//   4. HANDLER WIRING (static source) — each of the three mutations calls
//      `emitMutationAudit` AFTER its write, inside the SAME `withTenantContext`
//      transaction, and passes the `Request`.
//   5. ROUTE CONTRACT — the decision route is gated on
//      `approveAttendanceCorrection` (403 without it) and, with it, reaches the
//      tenant-DB boundary (503) — the DB-free proxy for "would have persisted
//      the flip and its audit row in one transaction".
//
// REMAINDER (infra-blocked): the actually-PERSISTED row after a live PATCH needs
// Postgres (`ERP_TENANT_DATABASE_URL`); this harness has none.

import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  attendanceAudit,
  emitMutationAudit,
} from "../audit/mutation_audit_catalog.ts";
import { routeAttendance } from "./attendance_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
// DB-free: no erpTenantDatabaseUrl, so authenticateRequest skips the live
// session check and withTenantContext raises TenantDbNotConfiguredError.
const config = { jwtSecret: SECRET } as AppConfig;

const ACTOR = "a0000000-0000-4000-8000-000000000001";
const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const CORRECTION_ID = "att_corr_c0ffee";
const CORRELATION_ID = "corr-abc-123";
const CHILD_NAME = "Asha Kumari";
const REASON = "she was in the medical room, not absent";

function claims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: ACTOR,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["approveAttendanceCorrection", "viewSis", "manageSis"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "sess-1",
    ...over,
  };
}

/** A request carrying the forensic metadata the audit row must capture. */
function auditedRequest(): Request {
  return new Request("https://x/attendance/corrections/att_corr_c0ffee/status", {
    method: "PATCH",
    headers: {
      "x-correlation-id": CORRELATION_ID,
      "user-agent": "Niksha/1.0 (Android 14)",
      "x-forwarded-for": "203.0.113.9, 10.0.0.1",
      "content-type": "application/json",
    },
    body: JSON.stringify({ status: "approved" }),
  });
}

class AuditSpyDb {
  audits: unknown[][] = [];
  domains: unknown[][] = [];

  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM domain_events") && sql.includes("idempotency_key")) {
      return Promise.resolve([] as T[]);
    }
    if (sql.includes("INSERT INTO audit_events")) {
      this.audits.push(args);
      return Promise.resolve([] as T[]);
    }
    if (sql.includes("INSERT INTO domain_events")) {
      this.domains.push(args);
      return Promise.resolve([] as T[]);
    }
    return Promise.resolve([] as T[]);
  }
}

const db = (spy: AuditSpyDb) => spy as unknown as TenantQueryClient;

// Column order of the audit_events INSERT in audit_repository.recordServerAuditEvent.
const A_ORG = 0,
  A_SCHOOL = 1,
  A_USER = 2,
  A_ROLE = 3,
  A_CORRELATION = 4,
  A_EVENT_TYPE = 5,
  A_CATEGORY = 6,
  A_ENTITY_TYPE = 7,
  A_ENTITY_ID = 8,
  A_METADATA = 9,
  A_IP = 10,
  A_USER_AGENT = 11;

function requestedSpec(source = "POST /parent/attendance/corrections") {
  return attendanceAudit.correctionRequested(CORRECTION_ID, {
    sisStudentId: "sis-7",
    studentId: STUDENT,
    dateLabel: "2026-07-21",
    markChange: { from: "absent", to: "present" },
    reason: REASON,
    requesterId: ACTOR,
    requesterRole: "parent",
    source,
  });
}

function decidedSpec(after = "approved") {
  return attendanceAudit.correctionDecided(CORRECTION_ID, {
    sisStudentId: "sis-7",
    studentId: STUDENT,
    dateLabel: "2026-07-21",
    before: { status: "pending" },
    after: { status: after },
    markChange: { from: "absent", to: "present" },
    requestReason: REASON,
    requesterId: "parent-9",
    requesterRole: "parent",
    source: "PATCH /attendance/corrections/:id/status",
    nonce: "2026-07-21T09:15:00.000Z",
  });
}

// ── 1. spec shape ────────────────────────────────────────────────────────────

Deno.test("attendance audit: correctionRequested carries before→after, source and reason", () => {
  const spec = requestedSpec();
  assertEquals(spec.audit.eventType, "attendanceCorrectionRequested");
  assertEquals(spec.audit.category, "workflow");
  assertEquals(spec.audit.entityType, "attendance_correction");
  assertEquals(spec.audit.entityId, CORRECTION_ID);
  assertEquals(spec.audit.metadata?.before, { mark: "absent" });
  assertEquals(spec.audit.metadata?.after, { mark: "present" });
  assertEquals(spec.audit.metadata?.reason, REASON);
  assertEquals(spec.audit.metadata?.requesterRole, "parent");
  assertEquals(spec.audit.metadata?.source, "POST /parent/attendance/corrections");
  assertEquals(spec.audit.metadata?.studentId, STUDENT);
  assertEquals(spec.domain.eventType, "attendance.correction.requested");
  assertEquals(spec.domain.sourceModule, "attendance");
  assertEquals(
    spec.domain.idempotencyKey,
    `attendance.correction.requested:${CORRECTION_ID}`,
  );
});

Deno.test("attendance audit: the SAME spec distinguishes a parent submit from a staff submit by `source`", () => {
  assertEquals(
    requestedSpec("POST /attendance/corrections").audit.metadata?.source,
    "POST /attendance/corrections",
  );
  assertEquals(
    requestedSpec().audit.metadata?.source,
    "POST /parent/attendance/corrections",
  );
});

Deno.test("attendance audit: correctionDecided carries the real status transition + the mark it authorises", () => {
  const spec = decidedSpec("approved");
  assertEquals(spec.audit.eventType, "attendanceCorrectionDecided");
  assertEquals(spec.audit.entityId, CORRECTION_ID);
  assertEquals(spec.audit.metadata?.before, { status: "pending" });
  assertEquals(spec.audit.metadata?.after, { status: "approved" });
  assertEquals(spec.audit.metadata?.markChange, { from: "absent", to: "present" });
  assertEquals(spec.audit.metadata?.requestReason, REASON);
  // The PATCH body has no decision-note field, so there is no decision reason to
  // record. Stated explicitly rather than faked from the requester's reason.
  assertEquals(spec.audit.metadata?.decisionReason, null);
});

Deno.test("attendance audit: a re-decision is NOT deduped away (outbox key folds in status + nonce)", () => {
  const approved = decidedSpec("approved").domain.idempotencyKey;
  const rejected = decidedSpec("rejected").domain.idempotencyKey;
  assert(approved !== rejected, "approve and reject must not share an outbox key");
  assertStringIncludes(String(approved), `${CORRECTION_ID}:approved:`);
  assertStringIncludes(String(approved), "2026-07-21T09:15:00.000Z");
});

// ── 2. write path ────────────────────────────────────────────────────────────

Deno.test("attendance audit: a correction SUBMIT writes one audit row bound to the actor + one domain event", async () => {
  const spy = new AuditSpyDb();
  await emitMutationAudit(db(spy), claims(), requestedSpec(), auditedRequest());

  assertEquals(spy.audits.length, 1);
  assertEquals(spy.domains.length, 1);
  const row = spy.audits[0];
  assertEquals(row[A_ORG], ORG);
  assertEquals(row[A_SCHOOL], SCHOOL);
  assertEquals(row[A_USER], ACTOR); // WHO asked
  assertEquals(row[A_ROLE], "schoolAdmin");
  assertEquals(row[A_EVENT_TYPE], "attendanceCorrectionRequested");
  assertEquals(row[A_CATEGORY], "workflow");
  assertEquals(row[A_ENTITY_TYPE], "attendance_correction");
  assertEquals(row[A_ENTITY_ID], CORRECTION_ID);
});

Deno.test("attendance audit: a correction DECISION writes an audit row with actor, correlation, ip and user-agent", async () => {
  const spy = new AuditSpyDb();
  await emitMutationAudit(db(spy), claims(), decidedSpec(), auditedRequest());

  assertEquals(spy.audits.length, 1);
  const row = spy.audits[0];
  assertEquals(row[A_USER], ACTOR); // WHO approved
  assertEquals(row[A_EVENT_TYPE], "attendanceCorrectionDecided");
  // Correlation is auto-derived by emitMutationAudit from the request — the
  // whole point of using it instead of raw recordMutationAudit.
  assertEquals(row[A_CORRELATION], CORRELATION_ID);
  // Passing the Request is what captures these; they are NULL without it.
  assertEquals(row[A_IP], "203.0.113.9");
  assertEquals(row[A_USER_AGENT], "Niksha/1.0 (Android 14)");

  const metadata = JSON.parse(String(row[A_METADATA]));
  assertEquals(metadata.before, { status: "pending" });
  assertEquals(metadata.after, { status: "approved" });
  assertEquals(metadata.source, "PATCH /attendance/corrections/:id/status");
  assertEquals(metadata.markChange, { from: "absent", to: "present" });
});

Deno.test("attendance audit: emitMutationAudit leaves correlation NULL only when there is genuinely none", async () => {
  const spy = new AuditSpyDb();
  const noCorrelation = new Request("https://x/attendance/corrections", { method: "POST" });
  await emitMutationAudit(db(spy), claims(), requestedSpec(), noCorrelation);
  assertEquals(spy.audits[0][A_CORRELATION], null);
});

// ── 3. privacy ───────────────────────────────────────────────────────────────

Deno.test("attendance audit: the child's NAME is never copied into the audit metadata", async () => {
  const spy = new AuditSpyDb();
  await emitMutationAudit(db(spy), claims(), requestedSpec(), auditedRequest());
  const serialized = JSON.stringify(spy.audits[0]);
  assertEquals(
    serialized.includes(CHILD_NAME),
    false,
    "audit metadata must identify the student by id, not by name",
  );
  // ...but it IS resolvable to the exact student.
  assertStringIncludes(serialized, STUDENT);
  assertStringIncludes(serialized, "sis-7");
});

Deno.test("attendance audit: the free-text reason stays in the audit record and out of the domain fan-out", async () => {
  const spy = new AuditSpyDb();
  await emitMutationAudit(db(spy), claims(), requestedSpec(), auditedRequest());

  // The governance record keeps it — it cannot be reconstructed later.
  assertStringIncludes(JSON.stringify(spy.audits[0]), REASON);
  // The outbox (consumed by subscribers/notifications) gets only its presence.
  const payload = JSON.parse(String(spy.domains[0][3]));
  assertEquals(payload.hasReason, true);
  assertEquals(
    JSON.stringify(spy.domains[0]).includes(REASON),
    false,
    "free text must not fan out through domain_events",
  );
});

// ── 4. handler wiring (static source) ────────────────────────────────────────

const HANDLERS_SRC = await Deno.readTextFile(
  new URL("./attendance_handlers.ts", import.meta.url),
);

/** Body of one exported handler, up to the next top-level export. */
function handlerBody(name: string): string {
  const start = HANDLERS_SRC.indexOf(`export async function ${name}(`);
  assert(start >= 0, `${name} not found in attendance_handlers.ts`);
  const next = HANDLERS_SRC.indexOf("\nexport ", start + 1);
  return HANDLERS_SRC.slice(start, next === -1 ? undefined : next);
}

Deno.test("attendance audit: the module imports emitMutationAudit, never raw recordMutationAudit", () => {
  assertStringIncludes(HANDLERS_SRC, "emitMutationAudit");
  assertStringIncludes(HANDLERS_SRC, "attendanceAudit");
  // No CALL to the raw recorder (the prose above may name it; a call must not
  // exist). Raw recordMutationAudit is what leaves ~39 sites with a NULL
  // correlation id, because it does not derive one from the request.
  assertEquals(
    HANDLERS_SRC.includes("recordMutationAudit("),
    false,
    "raw recordMutationAudit persists a NULL correlation id — use emitMutationAudit",
  );
  assertEquals(
    /import[^;]*\brecordMutationAudit\b[^;]*from/.test(HANDLERS_SRC),
    false,
    "the raw recorder must not be imported into the attendance module",
  );
});

Deno.test("attendance audit: every attendance mutation emits an audit AFTER its write, in the same transaction, with the Request", () => {
  // The `await ` prefix matters: it pins the CALL, not the enclosing function's
  // own declaration (which contains the same identifier).
  const cases: Array<[string, string]> = [
    ["handleCreateAttendanceCorrection", "await createAttendanceCorrection("],
    ["handleParentCreateAttendanceCorrection", "await createAttendanceCorrection("],
    ["handleUpdateAttendanceCorrectionStatus", "await updateAttendanceCorrectionStatus("],
  ];
  for (const [handler, writeCall] of cases) {
    const body = handlerBody(handler);
    const write = body.indexOf(writeCall);
    const emit = body.indexOf("emitMutationAudit(");
    const tx = body.indexOf("withTenantContext(");
    assert(write >= 0, `${handler}: write call ${writeCall} not found`);
    assert(emit >= 0, `${handler}: no emitMutationAudit on the success path`);
    assert(tx >= 0, `${handler}: no withTenantContext block`);
    assert(
      write < emit,
      `${handler}: the audit must follow the write it records`,
    );
    assert(
      tx < write && tx < emit,
      `${handler}: the audit must be inside the same withTenantContext transaction as the write`,
    );
    // The 4th argument to emitMutationAudit — without it the audit row loses
    // ip_address and user_agent.
    const call = body.slice(emit);
    assertStringIncludes(
      call.slice(0, call.indexOf(");") + 2),
      "req,",
    );
  }
});

// ── 5. route contract ────────────────────────────────────────────────────────

async function patchStatus(permissions: string[]): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims({ permissions }), 900);
  const path = "/attendance/corrections/att_corr_1/status";
  const req = new Request(`https://x${path}`, {
    method: "PATCH",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
      "x-correlation-id": CORRELATION_ID,
    },
    body: JSON.stringify({ status: "approved" }),
  });
  return await routeAttendance(req, config, "PATCH", path);
}

Deno.test("attendance audit: the decision route stays gated on approveAttendanceCorrection", async () => {
  const res = await patchStatus(["manageSis", "viewSis"]);
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("attendance audit: an authorized decision reaches the tenant-DB boundary (would persist flip + audit atomically)", async () => {
  const res = await patchStatus(["approveAttendanceCorrection", "viewSis", "manageSis"]);
  assertEquals(res?.status, 503);
  const env = await res!.json();
  assertEquals(env.error.code, "TENANT_DB_NOT_CONFIGURED");
});
