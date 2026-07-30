import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  ApprovalInvalidStateError,
  ApprovalSelfApproveDeniedError,
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
 * lookup, the seeded verifier for the exam_sessions probe, and echoes the
 * decided row + audit entry for the happy path.
 *
 * FAITHFUL to the terminal guard: decideApproval's decision UPDATE carries an
 * `AND status = 'pending'` predicate (the Money-Integrity race pattern) and
 * throws ApprovalInvalidStateError when it matches 0 rows. This FakeDb honours
 * that predicate instead of echoing an "approved" row unconditionally — so a
 * re-decide (row already approved/rejected) or a concurrent decide that lands
 * between read and write correctly matches 0 rows, and a LOST guard would flip
 * the affected re-decide tests RED instead of silently passing green.
 */
class FakeDb {
  constructor(
    private readonly current: ApprovalRequestRow,
    private readonly verifier: string | null,
    // Status the UPDATE's `AND status = 'pending'` predicate sees at WRITE time.
    // Defaults to the seeded row's status (a single, self-consistent row). Pass
    // a different value to model a TOCTOU race: the row is read `pending` (so
    // assertPending passes) but a concurrent actor decides it before this UPDATE
    // lands.
    private readonly statusAtUpdate: string = current.status,
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
      // Honour the terminal `AND status = 'pending'` guard exactly as Postgres
      // would: the UPDATE affects the row ONLY while it is still pending at
      // write time; otherwise it matches 0 rows (no-op). If the guard is ever
      // removed from the SQL, `guardsPending` goes false and the update echoes
      // unconditionally — surfacing the lost guard as a failing re-decide test.
      const guardsPending = sql.includes("status = 'pending'");
      if (guardsPending && this.statusAtUpdate !== "pending") {
        return Promise.resolve([] as T[]);
      }
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

function db(
  current: ApprovalRequestRow,
  verifier: string | null,
  statusAtUpdate?: string,
): TenantQueryClient {
  return new FakeDb(current, verifier, statusAtUpdate) as unknown as TenantQueryClient;
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

Deno.test("SoD — exam verifier check is exam-only (studentLeave self-approve is allowed)", async () => {
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

// ── SoD self-approve denial for value/money-gating approvals (PRI-1 / FIN-D4) ──

Deno.test("SoD — fee-concession requester cannot approve their OWN waiver (FIN-D4)", async () => {
  await assertRejects(
    () =>
      decideApproval(
        db(approval({ type: "feeConcession", entity_type: "fee_concession" }), null),
        ORG,
        SCHOOL,
        {
          approvalId: "appr_1",
          status: "approved",
          actorId: COORDINATOR, // same person who requested (requester_id default)
          actorName: "Coordinator",
        },
      ),
    ApprovalSelfApproveDeniedError,
  );
});

Deno.test("SoD — a different checker MAY approve a fee concession", async () => {
  const result = await decideApproval(
    db(approval({ type: "feeConcession", entity_type: "fee_concession" }), null),
    ORG,
    SCHOOL,
    {
      approvalId: "appr_1",
      status: "approved",
      actorId: PRINCIPAL, // different from the requester
      actorName: "Principal",
    },
  );
  assertEquals(result.status, "approved");
  assertEquals(result.decided_by_id, PRINCIPAL);
});

Deno.test("SoD — a refund requester cannot approve their OWN refund (money out)", async () => {
  await assertRejects(
    () =>
      decideApproval(
        db(approval({ type: "refund", entity_type: "refund" }), null),
        ORG,
        SCHOOL,
        {
          approvalId: "appr_1",
          status: "approved",
          actorId: COORDINATOR,
          actorName: "Coordinator",
        },
      ),
    ApprovalSelfApproveDeniedError,
  );
});

Deno.test("SoD — the requester CAN reject their own value-gating request (only approvals guarded)", async () => {
  const result = await decideApproval(
    db(approval({ type: "feeConcession", entity_type: "fee_concession" }), null),
    ORG,
    SCHOOL,
    {
      approvalId: "appr_1",
      status: "rejected",
      actorId: COORDINATOR,
      actorName: "Coordinator",
      comment: "withdrawn",
    },
  );
  assertEquals(result.status, "rejected");
});

// ── Re-decide / already-decided guard (double-decide, double-apply defense) ──
// A value/money-gating approval that is ALREADY decided must not be decided a
// second time — otherwise the domain effect (waive money / pay a refund out)
// double-applies. The guard lives in decideApproval (early assertPending on the
// fetched row AND the terminal `AND status = 'pending'` UPDATE + throw-on-0-rows).
// These tests, over the faithful FakeDb above, would fail RED if EITHER layer
// were lost.

Deno.test("re-decide — an already-approved fee concession cannot be approved again", async () => {
  const alreadyApproved = approval({
    type: "feeConcession",
    entity_type: "fee_concession",
    status: "approved",
    decided_by_id: PRINCIPAL,
    decided_by_name: "Principal",
    decided_at: "2026-06-12T01:00:00.000Z",
  });
  await assertRejects(
    () =>
      decideApproval(db(alreadyApproved, null), ORG, SCHOOL, {
        approvalId: "appr_1",
        status: "approved",
        actorId: PRINCIPAL, // second approver trying to re-approve
        actorName: "Principal",
      }),
    ApprovalInvalidStateError,
  );
});

Deno.test("re-decide — an already-rejected refund cannot be flipped to approved", async () => {
  const alreadyRejected = approval({
    type: "refund",
    entity_type: "refund",
    status: "rejected",
    decided_by_id: PRINCIPAL,
    decided_by_name: "Principal",
    decided_at: "2026-06-12T01:00:00.000Z",
    decision_comment: "not eligible",
  });
  await assertRejects(
    () =>
      decideApproval(db(alreadyRejected, null), ORG, SCHOOL, {
        approvalId: "appr_1",
        status: "approved",
        actorId: PRINCIPAL,
        actorName: "Principal",
      }),
    ApprovalInvalidStateError,
  );
});

Deno.test("re-decide — concurrent decide between read and write is caught by the guarded UPDATE (no double-apply)", async () => {
  // TOCTOU: the row is still 'pending' when fetched (so assertPending passes),
  // but a concurrent actor decides it before this UPDATE lands. The terminal
  // `AND status = 'pending'` predicate then matches 0 rows — decideApproval must
  // throw ApprovalInvalidStateError, NOT echo a second "approved" decision.
  const pendingAtRead = approval({ type: "feeConcession", entity_type: "fee_concession" });
  await assertRejects(
    () =>
      decideApproval(db(pendingAtRead, null, "approved"), ORG, SCHOOL, {
        approvalId: "appr_1",
        status: "approved",
        actorId: PRINCIPAL,
        actorName: "Principal",
      }),
    ApprovalInvalidStateError,
  );
});
