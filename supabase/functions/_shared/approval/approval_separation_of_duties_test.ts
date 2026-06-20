import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  ApprovalSeparationOfDutiesError,
  decideApproval,
} from "./approval_repository.ts";
import type { ApprovalRequestRow } from "./approval_types.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const COORDINATOR = "d1000000-0000-4000-8000-000000000001";
const PRINCIPAL = "d1000000-0000-4000-8000-000000000002";

function approval(overrides: Partial<ApprovalRequestRow> = {}): ApprovalRequestRow {
  return {
    id: "appr_1",
    organization_id: ORG,
    school_id: SCHOOL,
    type: "examResults",
    status: "pending",
    title: "Publish exam results",
    summary: "Term 2 Mathematics — 8A",
    requester_id: COORDINATOR,
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
    ...overrides,
  };
}

/**
 * Minimal stand-in for the tenant DB. Returns the seeded approval row for the
 * lookup, the seeded verifier for the exam_sessions probe, and echoes an
 * "approved" row + audit entry for the happy path.
 */
class FakeDb {
  constructor(
    private readonly current: ApprovalRequestRow,
    private readonly verifier: string | null,
  ) {}

  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM approval_requests")) {
      return Promise.resolve([this.current] as unknown as T[]);
    }
    if (sql.includes("coordinator_verified_by FROM exam_sessions")) {
      return Promise.resolve(
        [{ coordinator_verified_by: this.verifier }] as unknown as T[],
      );
    }
    if (sql.includes("UPDATE approval_requests")) {
      return Promise.resolve(
        [{
          ...this.current,
          status: String(args[0]),
          decided_by_id: String(args[1]),
          decided_by_name: String(args[2]),
        }] as unknown as T[],
      );
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

function db(current: ApprovalRequestRow, verifier: string | null): TenantQueryClient {
  return new FakeDb(current, verifier) as unknown as TenantQueryClient;
}

Deno.test("SoD — exam verifier cannot approve the same results", async () => {
  await assertRejects(
    () =>
      decideApproval(db(approval(), COORDINATOR), ORG, SCHOOL, {
        approvalId: "appr_1",
        status: "approved",
        actorId: COORDINATOR, // same person who verified
        actorName: "Coordinator",
      }),
    ApprovalSeparationOfDutiesError,
  );
});

Deno.test("SoD — a different approver may approve verified results", async () => {
  const result = await decideApproval(db(approval(), COORDINATOR), ORG, SCHOOL, {
    approvalId: "appr_1",
    status: "approved",
    actorId: PRINCIPAL, // different from verifier
    actorName: "Principal",
  });
  assertEquals(result.status, "approved");
  assertEquals(result.decided_by_id, PRINCIPAL);
});

Deno.test("SoD — approving an unverified exam (no verifier) is allowed", async () => {
  // If no one verified yet, the verify-step gate elsewhere handles it; SoD here
  // must not falsely trip on a null verifier.
  const result = await decideApproval(db(approval(), null), ORG, SCHOOL, {
    approvalId: "appr_1",
    status: "approved",
    actorId: COORDINATOR,
    actorName: "Coordinator",
  });
  assertEquals(result.status, "approved");
});

Deno.test("SoD — rejection by the verifier is allowed (not an approval)", async () => {
  const result = await decideApproval(db(approval(), COORDINATOR), ORG, SCHOOL, {
    approvalId: "appr_1",
    status: "rejected",
    actorId: COORDINATOR,
    actorName: "Coordinator",
    comment: "Recheck section B totals",
  });
  assertEquals(result.status, "rejected");
});

Deno.test("SoD — check is exam-only (does not affect other approval types)", async () => {
  const result = await decideApproval(
    db(approval({ type: "studentLeave", entity_type: "leave" }), COORDINATOR),
    ORG,
    SCHOOL,
    {
      approvalId: "appr_1",
      status: "approved",
      actorId: COORDINATOR,
      actorName: "Coordinator",
    },
  );
  assertEquals(result.status, "approved");
});
