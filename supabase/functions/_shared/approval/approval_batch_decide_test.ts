// PRI-1 — batch approve/reject on the Approval Center (multi-select decisions).
//
// The batch endpoint POST /approvals/batch-decide runs the SAME per-item
// decision path as the single endpoints, via the shared `decideOne`. This file
// proves, DB-free (spy DB capturing the writes), that:
//
//   1. Batch approve of N pending → all N decided + exactly N audit rows (one
//      per decision), none double-decided.
//   2. A mixed batch (one pending, one already-approved, one forbidden-type, one
//      missing) → correct decided/skipped split, no double-decision, no partial
//      abort — a bad/forbidden/non-pending id is reported in `skipped`.
//   3. Idempotency: re-deciding an already-decided id → skipped('not pending');
//      the pending-guarded UPDATE never fires twice on the same row.
//   4. SoD self-approve inside a batch → that id skipped('forbidden'), the rest
//      still decided.
//   5. reject without a comment → whole-batch 422 (mirrors the single-reject
//      422), no decision attempted.
//   6. Route reachability gate: viewManagement + school scope (403 without,
//      401 unauthenticated, 503 to DB with the gate satisfied — per-item
//      authority is still enforced inside the tenant tx).
//
// Route + reachability legs use routeApproval with a real signed JWT (like the
// QW4 route-contract test). The per-item decision legs drive the shared
// `decideOne` directly with a spy DB — the same seam the QW4 audit test uses on
// decideApproval/orchestrateApprovalDecision — because the actual pending
// transition + audit insert happen inside the tenant tx (needs no live DB here).

import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { ApprovalRequestRow } from "./approval_types.ts";
import { routeApproval } from "./approval_router.ts";
import { decideOne } from "./approval_handlers.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const REQUESTER = "d1000000-0000-4000-8000-000000000001";
const APPROVER = "d1000000-0000-4000-8000-000000000002";

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: APPROVER,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
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

function approval(id: string, over: Partial<ApprovalRequestRow> = {}): ApprovalRequestRow {
  return {
    id,
    organization_id: ORG,
    school_id: SCHOOL,
    type: "studentLeave",
    status: "pending",
    title: "Leave request",
    summary: "Half-day",
    requester_id: REQUESTER,
    requester_name: "Requester",
    entity_type: "leave",
    entity_id: `entity_${id}`,
    payload: {},
    decided_at: null,
    decided_by_id: null,
    decided_by_name: null,
    decision_comment: null,
    created_at: "2026-06-12T00:00:00.000Z",
    updated_at: "2026-06-12T00:00:00.000Z",
    ...over,
  };
}

interface AuditCapture {
  approvalId: string;
  action: string;
  actorId: string;
}

/**
 * Multi-row spy DB. Serves approvals by id, honours the pending-guarded UPDATE
 * (only a pending row transitions; the in-map status then flips so a repeat
 * decide sees non-pending → idempotency), captures every audit insert, and lets
 * the exam-verifier and class-teacher checks be configured per test.
 */
class BatchSpyDb {
  auditInserts: AuditCapture[] = [];
  updateAttempts: string[] = [];

  constructor(
    private readonly rows: Map<string, ApprovalRequestRow>,
    private readonly opts: {
      examVerifier?: string | null;
      classTeacherAllowed?: boolean;
    } = {},
  ) {}

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM approval_requests")) {
      const id = String(args[0]);
      const row = this.rows.get(id);
      return Promise.resolve((row ? [row] : []) as unknown as T[]);
    }
    if (sql.includes("coordinator_verified_by FROM exam_sessions")) {
      return Promise.resolve(
        [{ coordinator_verified_by: this.opts.examVerifier ?? null }] as unknown as T[],
      );
    }
    if (sql.includes("FROM teacher_assignments")) {
      // class-teacher scope probe → count string
      const allowed = this.opts.classTeacherAllowed ?? true;
      return Promise.resolve([{ count: allowed ? "1" : "0" }] as unknown as T[]);
    }
    if (sql.includes("UPDATE approval_requests")) {
      // Guarded UPDATE: status = $1 ... WHERE id = $5 AND ... AND status = 'pending'
      const status = String(args[0]);
      const id = String(args[4]);
      this.updateAttempts.push(id);
      const current = this.rows.get(id);
      if (!current || current.status !== "pending") {
        // Non-pending → the guarded UPDATE returns no rows (idempotency).
        return Promise.resolve([] as T[]);
      }
      const updated = { ...current, status };
      this.rows.set(id, updated); // flip so a repeat decide sees non-pending
      return Promise.resolve([updated] as unknown as T[]);
    }
    if (sql.includes("INSERT INTO approval_audit_entries")) {
      this.auditInserts.push({
        approvalId: String(args[2]),
        action: String(args[3]),
        actorId: String(args[4]),
      });
      return Promise.resolve([{ id: "audit", metadata: {} }] as unknown as T[]);
    }
    // Domain-effect writes + snapshot probes → benign empty (no-op effects).
    return Promise.resolve([] as T[]);
  }
}

function db(spy: BatchSpyDb): TenantQueryClient {
  return spy as unknown as TenantQueryClient;
}

const MGMT = claims(["viewManagement", "approveStudentLeave"]);

// ── (1) Batch approve of N pending → all decided + N audit rows ───────────────

Deno.test("PRI-1: batch approve of N pending → all decided, one audit row each, no double-decide", async () => {
  const rows = new Map([
    ["a", approval("a")],
    ["b", approval("b")],
    ["c", approval("c")],
  ]);
  const spy = new BatchSpyDb(rows);
  const decided: Array<{ id: string; status: string }> = [];
  const skipped: Array<{ id: string; reason: string }> = [];

  for (const id of ["a", "b", "c"]) {
    const out = await decideOne(db(spy), MGMT, ORG, SCHOOL, id, "approved", null, APPROVER, "Approver");
    if (out.kind === "decided") decided.push({ id, status: out.row.status });
    else skipped.push({ id, reason: out.kind });
  }

  assertEquals(decided.map((d) => d.id), ["a", "b", "c"]);
  assertEquals(decided.every((d) => d.status === "approved"), true);
  assertEquals(skipped.length, 0);
  // Exactly N audit rows — one decision each, the approver is the actor.
  assertEquals(spy.auditInserts.length, 3);
  assertEquals(spy.auditInserts.every((a) => a.action === "approved"), true);
  assertEquals(spy.auditInserts.every((a) => a.actorId === APPROVER), true);
  // Exactly N UPDATE attempts — none decided twice.
  assertEquals(spy.updateAttempts.sort(), ["a", "b", "c"]);
});

// ── (2) Mixed batch → correct decided/skipped split, no partial abort ─────────

Deno.test("PRI-1: mixed batch (pending / already-approved / forbidden-type / missing) → correct split, no abort", async () => {
  const rows = new Map([
    ["pending", approval("pending")],
    ["done", approval("done", { status: "approved" })],
    // examResults needs approveExamResults, which MGMT lacks → forbidden id.
    ["forbidden", approval("forbidden", { type: "examResults", entity_type: "exam_session" })],
  ]);
  const spy = new BatchSpyDb(rows, { examVerifier: null });
  const decided: Array<{ id: string; status: string }> = [];
  const skipped: Array<{ id: string; reason: string }> = [];

  for (const id of ["pending", "done", "forbidden", "missing"]) {
    const out = await decideOne(db(spy), MGMT, ORG, SCHOOL, id, "approved", null, APPROVER, "Approver");
    switch (out.kind) {
      case "decided":
        decided.push({ id, status: out.row.status });
        break;
      case "not_found":
        skipped.push({ id, reason: "not found" });
        break;
      case "denied":
        skipped.push({ id, reason: "forbidden" });
        break;
      case "invalid":
        skipped.push({ id, reason: "not pending" });
        break;
    }
  }

  assertEquals(decided, [{ id: "pending", status: "approved" }]);
  assertEquals(
    skipped.sort((x, y) => x.id.localeCompare(y.id)),
    [
      { id: "done", reason: "not pending" },
      { id: "forbidden", reason: "forbidden" },
      { id: "missing", reason: "not found" },
    ],
  );
  // Only the ONE pending id produced an audit row; forbidden/missing never
  // reached the transition, and 'done' was blocked by the pending guard.
  assertEquals(spy.auditInserts.length, 1);
  assertEquals(spy.auditInserts[0].approvalId, "pending");
  // The forbidden + missing ids never even attempted an UPDATE.
  assertEquals(spy.updateAttempts.includes("forbidden"), false);
  assertEquals(spy.updateAttempts.includes("missing"), false);
});

// ── (3) Idempotency — re-deciding a decided id is skipped, never re-decided ───

Deno.test("PRI-1: idempotency — an already-decided id in the batch is skipped('not pending'), no second audit row", async () => {
  const rows = new Map([["x", approval("x")]]);
  const spy = new BatchSpyDb(rows);

  const first = await decideOne(db(spy), MGMT, ORG, SCHOOL, "x", "approved", null, APPROVER, "Approver");
  assertEquals(first.kind, "decided");
  // Second pass on the same id (now approved) → guarded UPDATE no-ops → invalid.
  const second = await decideOne(db(spy), MGMT, ORG, SCHOOL, "x", "approved", null, APPROVER, "Approver");
  assertEquals(second.kind, "invalid");

  // One audit row total — the id was decided exactly once.
  assertEquals(spy.auditInserts.length, 1);
});

// ── (4) SoD self-approve inside a batch → that id skipped, rest decided ────────

Deno.test("PRI-1: SoD self-approve in a batch — the self-approved id is skipped('forbidden'), the rest proceed", async () => {
  // inventoryPo: the requester cannot approve their own PO (self-approve guard).
  // 'own' is requested by APPROVER (the decider) → must be skipped.
  const poPerms = claims(["viewManagement", "approvePurchaseOrder"]);
  const rows = new Map([
    ["own", approval("own", { type: "inventoryPo", entity_type: "purchase_order", requester_id: APPROVER })],
    ["other", approval("other", { type: "inventoryPo", entity_type: "purchase_order", requester_id: REQUESTER })],
  ]);
  const spy = new BatchSpyDb(rows);
  const decided: string[] = [];
  const skipped: string[] = [];

  for (const id of ["own", "other"]) {
    const out = await decideOne(db(spy), poPerms, ORG, SCHOOL, id, "approved", null, APPROVER, "Approver");
    if (out.kind === "decided") decided.push(id);
    else if (out.kind === "denied") skipped.push(id);
  }

  assertEquals(skipped, ["own"]); // self-approve blocked → skipped, not aborting
  assertEquals(decided, ["other"]); // batch continued
  // Only 'other' produced an audit row; the self-approve never transitioned.
  assertEquals(spy.auditInserts.length, 1);
  assertEquals(spy.auditInserts[0].approvalId, "other");
  assertEquals(spy.updateAttempts.includes("own"), false);
});

// ── (4b) SoD self-approve of a MONEY waiver in a batch → skipped (FIN-D4) ──────

Deno.test("PRI-1: a fee-concession maker approving their OWN waiver in a batch is skipped (FIN-D4 maker-checker not bypassed)", async () => {
  // feeConcession waives money — the requester may not approve it, on the batch
  // path just as on the single path. 'own' is requested by APPROVER (the decider).
  const perms = claims(["viewManagement", "approveFeeConcession"]);
  const rows = new Map([
    ["own", approval("own", { type: "feeConcession", entity_type: "fee_concession", requester_id: APPROVER })],
  ]);
  const spy = new BatchSpyDb(rows);

  const out = await decideOne(db(spy), perms, ORG, SCHOOL, "own", "approved", null, APPROVER, "Approver");
  assertEquals(out.kind, "denied"); // self-approve blocked → skipped, not decided
  assertEquals(spy.auditInserts.length, 0); // never transitioned → no audit
  assertEquals(spy.updateAttempts.includes("own"), false);
});

// ── (5) SoD exam verifier inside a batch → that id skipped ────────────────────

Deno.test("PRI-1: SoD exam-verifier in a batch — the verifier's own results id is skipped('forbidden')", async () => {
  const examPerms = claims(["viewManagement", "approveExamResults"]);
  const rows = new Map([
    ["exam", approval("exam", { type: "examResults", entity_type: "exam_session" })],
  ]);
  // The decider (APPROVER) is the coordinator who verified → SoD denies.
  const spy = new BatchSpyDb(rows, { examVerifier: APPROVER });

  const out = await decideOne(db(spy), examPerms, ORG, SCHOOL, "exam", "approved", null, APPROVER, "Approver");
  assertEquals(out.kind, "denied");
  assertEquals(spy.auditInserts.length, 0);
});

// ── (6) reject-without-comment → whole-batch 422 (route level) ────────────────

function post(token: string | null, path: string, body?: unknown): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  return new Request(`https://x${path}`, {
    method: "POST",
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

Deno.test("PRI-1: batch reject without a comment → 422 (mirrors the single-reject 422)", async () => {
  const token = await signAccessToken(SECRET, MGMT, 900);
  const res = await routeApproval(
    post(token, "/approvals/batch-decide", { ids: ["a", "b"], decision: "reject" }),
    config,
    "POST",
    "/approvals/batch-decide",
  );
  assertEquals(res?.status, 422);
  const env = await res!.json();
  assertEquals(env.error.code, "VALIDATION_ERROR");
});

Deno.test("PRI-1: batch reject with a blank-whitespace comment → 422", async () => {
  const token = await signAccessToken(SECRET, MGMT, 900);
  const res = await routeApproval(
    post(token, "/approvals/batch-decide", { ids: ["a"], decision: "reject", comment: "   " }),
    config,
    "POST",
    "/approvals/batch-decide",
  );
  assertEquals(res?.status, 422);
});

Deno.test("PRI-1: batch-decide with an empty ids array → 422", async () => {
  const token = await signAccessToken(SECRET, MGMT, 900);
  const res = await routeApproval(
    post(token, "/approvals/batch-decide", { ids: [], decision: "approve" }),
    config,
    "POST",
    "/approvals/batch-decide",
  );
  assertEquals(res?.status, 422);
});

Deno.test("PRI-1: batch-decide with a bad decision verb → 422", async () => {
  const token = await signAccessToken(SECRET, MGMT, 900);
  const res = await routeApproval(
    post(token, "/approvals/batch-decide", { ids: ["a"], decision: "cancel" }),
    config,
    "POST",
    "/approvals/batch-decide",
  );
  assertEquals(res?.status, 422);
});

// ── (6b) Route reachability gate: 401 / 403 / 503 ─────────────────────────────

Deno.test("PRI-1: batch-decide rejects an unauthenticated caller (401)", async () => {
  const res = await routeApproval(
    post(null, "/approvals/batch-decide", { ids: ["a"], decision: "approve" }),
    config,
    "POST",
    "/approvals/batch-decide",
  );
  assertEquals(res?.status, 401);
});

Deno.test("PRI-1: batch-decide denies a caller without viewManagement (reachability gate, 403)", async () => {
  const token = await signAccessToken(SECRET, claims(["approveStudentLeave"]), 900);
  const res = await routeApproval(
    post(token, "/approvals/batch-decide", { ids: ["a"], decision: "approve" }),
    config,
    "POST",
    "/approvals/batch-decide",
  );
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("PRI-1: batch-decide denies organization scope (school-scope gate, 403)", async () => {
  const token = await signAccessToken(
    SECRET,
    claims(["viewManagement"], { scope: "organization", school_id: null }),
    900,
  );
  const res = await routeApproval(
    post(token, "/approvals/batch-decide", { ids: ["a"], decision: "approve" }),
    config,
    "POST",
    "/approvals/batch-decide",
  );
  assertEquals(res?.status, 403);
});

Deno.test("PRI-1: batch-decide with the reachability gate satisfied + valid body reaches the DB (503)", async () => {
  // viewManagement + school scope pass the gate; the per-item authority runs
  // inside the tenant tx, which is unconfigured here → 503.
  const token = await signAccessToken(SECRET, MGMT, 900);
  const res = await routeApproval(
    post(token, "/approvals/batch-decide", { ids: ["a", "b"], decision: "approve" }),
    config,
    "POST",
    "/approvals/batch-decide",
  );
  assertEquals(res?.status, 503);
});

Deno.test("PRI-1: 'batch-decide' is routed as the batch handler, not captured as an approval id", async () => {
  // The literal segment must not be swallowed by the /{id} matchers; an
  // unauthenticated call still hits the batch handler (401), proving the route
  // matched (a UUID-id matcher would return null for this non-UUID segment).
  const res = await routeApproval(
    post(null, "/approvals/batch-decide"),
    config,
    "POST",
    "/approvals/batch-decide",
  );
  assertExists(res);
  assertEquals(res!.status, 401);
});
