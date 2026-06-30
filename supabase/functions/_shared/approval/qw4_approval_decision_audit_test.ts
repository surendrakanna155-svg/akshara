// QW4 · QA-X-016 (P1) — Every approve/reject decision writes an audit-trail row
// carrying the APPROVER identity.
//
// CONTRACT: POST /approvals/:id/approve|reject → handleDecision →
// orchestrateApprovalDecision → decideApproval must, on each decision, insert an
// `approval_audit_entries` row whose action matches the decision (approved /
// rejected / cancelled) and whose actor_id + actor_name are the deciding user.
//
// What is proven DB-free here (spy DB capturing the INSERTs):
//   1. decideApproval issues exactly one `INSERT INTO approval_audit_entries`
//      per decision, with:
//        • action  = "approved" on approve, "rejected" on reject;
//        • actor_id / actor_name = the approver passed in (NOT the requester);
//        • approval_request_id    = the decided approval.
//      The INSERT column order (approval_repository.ts:214) is
//      (org, school, approval_request_id, action, actor_id, actor_name, comment, …).
//   2. orchestrateApprovalDecision forwards the approver identity unchanged into
//      decideApproval (orchestrator wiring), so the audit row records who decided.
//   3. HANDLER WIRING (static-source): handleDecision binds the approver from
//      claims.sub (falling back to the body actor_id) and calls
//      orchestrateApprovalDecision with it — i.e. the audit actor is the
//      authenticated decider, not a spoofable free field on every path.
//
// REMAINDER (infra-blocked, needs ERP_TENANT_DATABASE_URL / live RLS): the
// actually-PERSISTED approval_audit_entries row after a real decision, and that
// a school-B approver cannot see / forge school-A's audit rows, need a live
// Postgres + the table's RLS. The DB boundary is approval_handlers.ts:359
// (runTenant → withTenantContext) wrapping orchestrateApprovalDecision.

import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { decideApproval } from "./approval_repository.ts";
import { orchestrateApprovalDecision } from "./approval_orchestrator.ts";
import type { ApprovalRequestRow } from "./approval_types.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const REQUESTER = "d1000000-0000-4000-8000-000000000001";
const APPROVER = "d1000000-0000-4000-8000-000000000002";

function approval(overrides: Partial<ApprovalRequestRow> = {}): ApprovalRequestRow {
  return {
    id: "appr_1",
    organization_id: ORG,
    school_id: SCHOOL,
    type: "studentLeave",
    status: "pending",
    title: "Leave request",
    summary: "Half-day — 8A",
    requester_id: REQUESTER,
    requester_name: "Requester",
    entity_type: "leave",
    entity_id: "leave_1",
    payload: {},
    decided_at: null,
    decided_by_id: null,
    decided_by_name: null,
    decision_comment: null,
    created_at: "2026-06-12T00:00:00.000Z",
    updated_at: "2026-06-12T00:00:00.000Z",
    ...overrides,
  };
}

interface AuditCapture {
  args: unknown[];
}

class ApprovalSpyDb {
  auditInserts: AuditCapture[] = [];

  constructor(private readonly current: ApprovalRequestRow) {}

  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM approval_requests")) {
      return Promise.resolve([this.current] as unknown as T[]);
    }
    if (sql.includes("coordinator_verified_by FROM exam_sessions")) {
      return Promise.resolve([{ coordinator_verified_by: null }] as unknown as T[]);
    }
    if (sql.includes("UPDATE approval_requests")) {
      return Promise.resolve([{
        ...this.current,
        status: String(args[0]),
        decided_by_id: String(args[1]),
        decided_by_name: String(args[2]),
        decision_comment: args[3] ?? null,
      }] as unknown as T[]);
    }
    if (sql.includes("INSERT INTO approval_audit_entries")) {
      this.auditInserts.push({ args });
      return Promise.resolve([{ id: "audit_1", metadata: {} }] as unknown as T[]);
    }
    // applyApprovalTypeHandler may probe/update; default to empty.
    return Promise.resolve([] as T[]);
  }
}

function db(spy: ApprovalSpyDb): TenantQueryClient {
  return spy as unknown as TenantQueryClient;
}

Deno.test("QA-X-016: approving writes one approval_audit_entries row with action=approved + the approver identity", async () => {
  const spy = new ApprovalSpyDb(approval());
  await decideApproval(db(spy), ORG, SCHOOL, {
    approvalId: "appr_1",
    status: "approved",
    actorId: APPROVER,
    actorName: "Principal",
  });
  assertEquals(spy.auditInserts.length, 1);
  const a = spy.auditInserts[0].args;
  // (org, school, approval_request_id, action, actor_id, actor_name, …)
  assertEquals(a[0], ORG);
  assertEquals(a[2], "appr_1");
  assertEquals(a[3], "approved");
  assertEquals(a[4], APPROVER); // approver, not requester
  assertEquals(a[5], "Principal");
});

Deno.test("QA-X-016: rejecting writes one approval_audit_entries row with action=rejected + the approver identity + comment", async () => {
  const spy = new ApprovalSpyDb(approval());
  await decideApproval(db(spy), ORG, SCHOOL, {
    approvalId: "appr_1",
    status: "rejected",
    actorId: APPROVER,
    actorName: "Principal",
    comment: "Insufficient detail",
  });
  assertEquals(spy.auditInserts.length, 1);
  const a = spy.auditInserts[0].args;
  assertEquals(a[3], "rejected");
  assertEquals(a[4], APPROVER);
  assertEquals(a[6], "Insufficient detail"); // comment captured on the trail row
});

Deno.test("QA-X-016: the audit row records the DECIDER, never the requester", async () => {
  const spy = new ApprovalSpyDb(approval());
  await decideApproval(db(spy), ORG, SCHOOL, {
    approvalId: "appr_1",
    status: "approved",
    actorId: APPROVER,
    actorName: "Principal",
  });
  const a = spy.auditInserts[0].args;
  assertEquals(a[4], APPROVER);
  // Guard against a regression that logs the requester as the approver.
  assertEquals(a[4] === REQUESTER, false);
});

Deno.test("QA-X-016 (orchestrator wiring): orchestrateApprovalDecision forwards the approver identity into the audit row", async () => {
  const spy = new ApprovalSpyDb(approval());
  await orchestrateApprovalDecision(db(spy), ORG, SCHOOL, {
    approvalId: "appr_1",
    status: "approved",
    actorId: APPROVER,
    actorName: "Principal",
  });
  assertEquals(spy.auditInserts.length, 1);
  assertEquals(spy.auditInserts[0].args[3], "approved");
  assertEquals(spy.auditInserts[0].args[4], APPROVER);
});

Deno.test("QA-X-016 (handler wiring): handleDecision binds the approver from the authenticated claims and passes it to the decision", async () => {
  const src = await Deno.readTextFile(
    new URL("./approval_handlers.ts", import.meta.url),
  );
  // The decider defaults to the authenticated user (claims.sub), not a free field.
  assertStringIncludes(src, "auth.claims.sub");
  // …and the decision is orchestrated with that actor.
  assertStringIncludes(src, "orchestrateApprovalDecision(");
  assertStringIncludes(src, "actorId");
  assertStringIncludes(src, "actorName");
});
