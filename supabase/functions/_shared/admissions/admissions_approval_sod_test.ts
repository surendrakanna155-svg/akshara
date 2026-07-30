import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  AdmissionsSelfApproveDeniedError,
  setApprovalDecision,
  submitApplication,
} from "./admissions_repository.ts";

// Owner-approved SoD (2026-07-03): the person who SUBMITTED an admissions
// application (the maker) may not APPROVE it (the checker), because approval
// flips the application to 'approved' and unblocks a fee handoff (a payable) —
// mirroring the FIN-D4 / generic-approval self-approve guard.
//
// These exercise the REAL repository path with a fake TenantQueryClient that
// models the approval row, the application's submitted_by (maker), and the
// application status. The key money-safety assertion: on a blocked self-approve
// the application NEVER transitions to 'approved' — so no enrollment / fee
// handoff can ever be triggered off it.

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const APPROVAL = "ac000000-0000-4000-8000-000000000001";
const APPLICATION = "ab000000-0000-4000-8000-000000000001";
const MAKER = "d0000000-0000-4000-8000-000000000001"; // submitted the application
const OTHER = "d0000000-0000-4000-8000-000000000002"; // a different approver

type Row = Record<string, unknown>;

class MockApprovalDb {
  application: Row = {
    id: APPLICATION,
    organization_id: ORG,
    school_id: SCHOOL,
    status: "submitted",
    submitted_by: MAKER,
  };
  approval: Row = {
    id: APPROVAL,
    organization_id: ORG,
    school_id: SCHOOL,
    application_id: APPLICATION,
    student_name: "SoD Student",
    class_label: "Grade 1",
    parent_name: "Parent One",
    counselor: "",
    decision: "pending",
    ai_score: 75,
    submitted_at: "2026-07-03T00:00:00.000Z",
    decided_by: null,
    decided_at: null,
    created_at: "2026-07-03T00:00:00.000Z",
    updated_at: "2026-07-03T00:00:00.000Z",
  };

  approvalUpdateCount = 0;
  applicationStatusUpdateCount = 0;

  // deno-lint-ignore no-explicit-any
  async queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    // getApprovalById
    if (sql.includes("FROM admissions_approvals ap")) {
      const match = this.approval.id === args[0] &&
        this.approval.organization_id === args[1] &&
        this.approval.school_id === args[2];
      return (match
        ? [{ ...this.approval, documents_complete: 0, documents_total: 0 }]
        : []) as T[];
    }
    // Maker lookup for the SoD guard.
    if (sql.includes("SELECT submitted_by FROM admissions_applications")) {
      const match = this.application.id === args[0] &&
        this.application.organization_id === args[1] &&
        this.application.school_id === args[2];
      return (match
        ? [{ submitted_by: this.application.submitted_by }]
        : []) as T[];
    }
    // Approval decision write (checker recorded).
    if (
      sql.includes("UPDATE admissions_approvals SET") &&
      sql.includes("decision = $4")
    ) {
      // Honor the terminal `AND decision = 'pending'` guard (RT round-3 S4): an
      // already-decided approval matches 0 rows → no re-decide / flip.
      if (this.approval.decision !== "pending") return [] as T[];
      this.approvalUpdateCount += 1;
      this.approval.decision = args[3];
      this.approval.decided_by = args[4];
      this.approval.decided_at = "2026-07-03T01:00:00.000Z";
      return [{ ...this.approval }] as T[];
    }
    // Application status flip on approve/reject — the money-path gate.
    if (
      sql.includes("UPDATE admissions_applications SET status = 'approved'")
    ) {
      this.applicationStatusUpdateCount += 1;
      this.application.status = "approved";
      return [] as T[];
    }
    if (
      sql.includes("UPDATE admissions_applications SET status = 'rejected'")
    ) {
      this.applicationStatusUpdateCount += 1;
      this.application.status = "rejected";
      return [] as T[];
    }
    // submitApplication draft → submitted (records submitted_by).
    if (sql.includes("status = 'submitted'")) {
      if (this.application.status !== "draft") return [] as T[];
      this.application.status = "submitted";
      this.application.submitted_by = args[3];
      this.application.submitted_at = "2026-07-03T00:30:00.000Z";
      return [{ ...this.application }] as T[];
    }
    throw new Error(`Unhandled SQL in MockApprovalDb: ${sql.slice(0, 80)}`);
  }
}

Deno.test("SoD: submitter approving their own application → SELF_APPROVE_DENIED, application NOT approved (no payable)", async () => {
  const db = new MockApprovalDb();

  await assertRejects(
    () =>
      setApprovalDecision(
        db as unknown as TenantQueryClient,
        ORG,
        SCHOOL,
        APPROVAL,
        "approved",
        MAKER, // checker === maker → blocked
      ),
    AdmissionsSelfApproveDeniedError,
  );

  // The guard fired BEFORE any write: approval still pending, application still
  // 'submitted' (never 'approved') → no enrollment / fee handoff can be triggered.
  assertEquals(db.approvalUpdateCount, 0, "approval decision never written");
  assertEquals(db.applicationStatusUpdateCount, 0, "application never flipped");
  assertEquals(db.approval.decision, "pending");
  assertEquals(db.application.status, "submitted");
});

Deno.test("RT round-3 S4: an already-decided approval cannot be re-decided or flipped (pending guard → null, no application flip)", async () => {
  const db = new MockApprovalDb();
  // A first checker already approved it; a concurrent/late second decide arrives.
  db.approval.decision = "approved";
  db.approval.decided_by = OTHER;

  const result = await setApprovalDecision(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    APPROVAL,
    "rejected", // an attempted flip approved → rejected
    "checker-3",
  );

  assertEquals(result, null, "a decided approval is not re-decidable (0 rows via the pending guard)");
  assertEquals(db.approval.decision, "approved", "decision NOT flipped to rejected");
  assertEquals(db.applicationStatusUpdateCount, 0, "no application status change on a no-op decide");
});

Deno.test("SoD: a DIFFERENT approver approves successfully → application approved + checker recorded", async () => {
  const db = new MockApprovalDb();

  const result = await setApprovalDecision(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    APPROVAL,
    "approved",
    OTHER, // checker !== maker → allowed
  );

  assertEquals(result?.decision, "approved");
  assertEquals(result?.decided_by, OTHER, "checker id recorded on decision");
  assertEquals(db.applicationStatusUpdateCount, 1, "application flipped to approved");
  assertEquals(db.application.status, "approved");
});

Deno.test("reject path is unaffected by SoD — even the submitter may reject (no payable created)", async () => {
  const db = new MockApprovalDb();

  const result = await setApprovalDecision(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    APPROVAL,
    "rejected",
    MAKER, // same person; reject is not guarded
  );

  assertEquals(result?.decision, "rejected");
  assertEquals(result?.decided_by, MAKER, "checker id recorded on reject too");
  assertEquals(db.application.status, "rejected");
});

Deno.test("submitApplication records submitted_by (the maker) so the SoD guard has an identity", async () => {
  const db = new MockApprovalDb();
  db.application.status = "draft";
  db.application.submitted_by = null;

  const submitted = await submitApplication(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    APPLICATION,
    MAKER,
  );

  assertEquals(submitted?.status, "submitted");
  assertEquals(submitted?.submitted_by, MAKER, "submitter captured as maker");
});

Deno.test("SoD is a no-op when submitted_by is NULL (pre-migration rows) — approval still proceeds", async () => {
  const db = new MockApprovalDb();
  db.application.submitted_by = null; // legacy application submitted before the SoD migration

  const result = await setApprovalDecision(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    APPROVAL,
    "approved",
    MAKER, // would be a self-approve, but no maker recorded → not blocked
  );

  assertEquals(result?.decision, "approved");
  assertEquals(db.application.status, "approved");
});
