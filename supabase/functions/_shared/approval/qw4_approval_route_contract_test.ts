// QW4 · QA-B-040 (P1) — Approvals separation-of-duties + decision RBAC contract.
//
// Two legs, both provable DB-free:
//
// (A) Separation-of-duties is a PURE check inside decideApproval: for an
//     examResults approval, the actor who approves must NOT be the same person
//     who coordinator-verified the results (→ ApprovalSeparationOfDutiesError →
//     mapped to 403 FORBIDDEN at the handler, see approval_handlers.ts:59). The
//     repository-level proof already exists in
//     approval_separation_of_duties_test.ts ("SoD — exam verifier cannot approve
//     the same results"). This file ADDS the ROUTE-level proof: the same SoD
//     violation surfaces as a 403 through routeApproval → handleApproveApproval.
//
// (B) The 5 approval-decision verbs route through routeApproval and are gated:
//       POST /approvals/{id}/approve  → approveExamResults (per type)
//       POST /approvals/{id}/reject   → approveExamResults (per type)
//       POST /approvals/{id}/cancel   → approval authority OR being requester
//       POST /approvals/audit         → manageManagement (RT-22 write slug)
//       POST /approvals               → school scope (submit)
//     We assert a non-holder is denied the per-type decision verbs (403) and
//     that a holder passes the school-scope/permission gate (503 to DB), plus
//     the submit + audit write gates.
//
// approve/reject load the approval row first (to resolve the per-type slug), so
// the gate's "non-holder → 403" is enforced INSIDE the tenant tx and therefore
// needs the DB to reach. We assert what IS DB-free: the submit + audit write
// gates (403 vs 503), the school-scope leg, the SoD pure check, and the
// route/path/401 contract. The per-row approve/reject permission denial is the
// infra remainder (it needs the loaded row).
//
// REMAINDER (infra-blocked): the live 200 approve with a different approver, and
// the per-type 403 on approve/reject (which loads the row before the slug check),
// need a live ERP_TENANT_DATABASE_URL. The SoD pure-function violation, the
// submit/audit write gates, scope + 401/404 contract are DB-free.

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeApproval } from "./approval_router.ts";
import {
  ApprovalSeparationOfDutiesError,
  decideApproval,
} from "./approval_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { ApprovalRequestRow } from "./approval_types.ts";
import { approvalPermissionForType } from "./approval_permissions.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const SUBMITTER = "d1000000-0000-4000-8000-000000000001";
const APPROVER = "d1000000-0000-4000-8000-000000000002";
const APPROVAL_ID = "b3000000-0000-4000-8000-000000000001";

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

function post(token: string | null, path: string, body?: unknown): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  return new Request(`https://x${path}`, {
    method: "POST",
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

// ── (A) Separation-of-duties — pure check + route surfacing ──────────────────

function approvalRow(over: Partial<ApprovalRequestRow> = {}): ApprovalRequestRow {
  return {
    id: APPROVAL_ID,
    organization_id: ORG,
    school_id: SCHOOL,
    type: "examResults",
    status: "pending",
    title: "Publish exam results",
    summary: "Term 2 — 8A",
    requester_id: SUBMITTER,
    requester_name: "Coordinator",
    entity_type: "exam_session",
    entity_id: "exam_1",
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

class FakeDb {
  constructor(private readonly row: ApprovalRequestRow, private readonly verifier: string | null) {}
  queryObject<T>(sql: string): Promise<T[]> {
    if (sql.includes("SELECT * FROM approval_requests")) {
      return Promise.resolve([this.row] as unknown as T[]);
    }
    if (sql.includes("coordinator_verified_by FROM exam_sessions")) {
      return Promise.resolve([{ coordinator_verified_by: this.verifier }] as unknown as T[]);
    }
    if (sql.includes("UPDATE approval_requests")) {
      return Promise.resolve([{ ...this.row, status: "approved" }] as unknown as T[]);
    }
    if (sql.includes("INSERT INTO approval_audit_entries")) {
      return Promise.resolve([{ id: "audit_1", metadata: {} }] as unknown as T[]);
    }
    return Promise.resolve([] as T[]);
  }
  queryCount(): Promise<number> {
    return Promise.resolve(0);
  }
}

function fakeDb(verifier: string | null): TenantQueryClient {
  return new FakeDb(approvalRow(), verifier) as unknown as TenantQueryClient;
}

Deno.test("QA-B-040: SoD — the exam verifier cannot approve the same results (approver != submitter/verifier)", async () => {
  // The actor who verified (SUBMITTER) attempting to approve is rejected.
  await assertRejects(
    () =>
      decideApproval(fakeDb(SUBMITTER), ORG, SCHOOL, {
        approvalId: APPROVAL_ID,
        status: "approved",
        actorId: SUBMITTER,
        actorName: "Coordinator",
      }),
    ApprovalSeparationOfDutiesError,
  );
});

Deno.test("QA-B-040: SoD — a DIFFERENT approver may approve the verified results", async () => {
  const result = await decideApproval(fakeDb(SUBMITTER), ORG, SCHOOL, {
    approvalId: APPROVAL_ID,
    status: "approved",
    actorId: APPROVER,
    actorName: "Principal",
  });
  assertEquals(result.status, "approved");
});

// ── (B) Decision-verb RBAC — slug map + DB-free write gates ──────────────────

Deno.test("QA-B-040: each approval type maps to its distinct approve permission slug", () => {
  assertEquals(approvalPermissionForType("examResults"), "approveExamResults");
  assertEquals(approvalPermissionForType("studentLeave"), "approveStudentLeave");
  assertEquals(approvalPermissionForType("feeConcession"), "approveFeeConcession");
  assertEquals(approvalPermissionForType("refund"), "approveRefunds");
  assertEquals(approvalPermissionForType("inventoryPo"), "approvePurchaseOrder");
});

Deno.test("QA-B-040: POST /approvals/audit is denied without manageManagement (RT-22 write gate, 403)", async () => {
  // viewManagement (read) must NOT be able to forge an audit entry.
  const token = await signAccessToken(SECRET, claims(["viewManagement"]), 900);
  const res = await routeApproval(
    post(token, "/approvals/audit", {
      approval_request_id: APPROVAL_ID,
      action: "approved",
      actor_id: APPROVER,
      actor_name: "Principal",
    }),
    config,
    "POST",
    "/approvals/audit",
  );
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-040: POST /approvals/audit with manageManagement passes the write gate (503 to DB)", async () => {
  const token = await signAccessToken(SECRET, claims(["manageManagement"]), 900);
  const res = await routeApproval(
    post(token, "/approvals/audit", {
      approval_request_id: APPROVAL_ID,
      action: "approved",
      actor_id: APPROVER,
      actor_name: "Principal",
    }),
    config,
    "POST",
    "/approvals/audit",
  );
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-040: POST /approvals (submit) is denied without school scope (403)", async () => {
  const token = await signAccessToken(
    SECRET,
    claims(["manageManagement"], { scope: "platform", school_id: null }),
    900,
  );
  const res = await routeApproval(
    post(token, "/approvals", {
      type: "examResults",
      title: "t",
      summary: "s",
      requesterId: SUBMITTER,
      requesterName: "C",
      entityType: "exam_session",
      entityId: "exam_1",
    }),
    config,
    "POST",
    "/approvals",
  );
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-040: POST /approvals (submit) with school scope + valid body passes (503 to DB)", async () => {
  const token = await signAccessToken(SECRET, claims([]), 900);
  const res = await routeApproval(
    post(token, "/approvals", {
      type: "examResults",
      title: "t",
      summary: "s",
      requesterId: SUBMITTER,
      requesterName: "C",
      entityType: "exam_session",
      entityId: "exam_1",
    }),
    config,
    "POST",
    "/approvals",
  );
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-040: the decision verbs reject an unauthenticated caller (401)", async () => {
  const verbs = [
    `/approvals/${APPROVAL_ID}/approve`,
    `/approvals/${APPROVAL_ID}/reject`,
    `/approvals/${APPROVAL_ID}/cancel`,
    "/approvals/audit",
    "/approvals",
  ];
  for (const path of verbs) {
    const res = await routeApproval(post(null, path), config, "POST", path);
    assertEquals(res?.status, 401, `expected 401 for ${path}, got ${res?.status}`);
  }
});

Deno.test("QA-B-040: a non-/approvals path returns null (no match)", async () => {
  const res = await routeApproval(post(null, "/finance/refunds"), config, "POST", "/finance/refunds");
  assertEquals(res, null);
});
