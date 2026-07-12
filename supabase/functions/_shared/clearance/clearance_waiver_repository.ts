// SCE-1 slice 3 — Student Clearance dues-waiver repository (maker-checker).
//
// A maker raises a waiver (snapshotting the blocking dues as they stand); a
// DIFFERENT checker approves/rejects it (separation of duties enforced in
// decide — maker_id != checker_id, mirroring FIN-D4 / HR-3 leave). Only an
// APPROVED, un-consumed waiver that still covers the current dues lets the
// clearance gate pass; it is CONSUMED (single-use) when the lifecycle event
// issues. All access is explicitly org+school bound.

import type { TenantQueryClient } from "../tenant_db.ts";

export const WAIVER_LIFECYCLES = [
  "transfer_certificate",
  "transfer",
  "alumni_conversion",
  "promotion",
  "year_close",
] as const;
export type WaiverLifecycle = (typeof WAIVER_LIFECYCLES)[number];

export class ClearanceWaiverError extends Error {
  readonly code: string;
  readonly status: number;
  constructor(code: string, message: string, status = 422) {
    super(message);
    this.name = "ClearanceWaiverError";
    this.code = code;
    this.status = status;
  }
}

export interface ClearanceScopeIds {
  organizationId: string;
  schoolId: string;
}

export interface ClearanceWaiverRow {
  id: string;
  student_id: string;
  student_name?: string | null; // populated only by the queue join (audit slice-4 P2)
  lifecycle: string;
  reason: string;
  blocking_amount: string | null;
  status: string;
  maker_id: string;
  checker_id: string | null;
  decided_at: string | null;
  consumed_by_issue_id: string | null;
  consumed_at: string | null;
  created_at: string;
}

const COLUMNS =
  `id, student_id, lifecycle, reason, blocking_amount::text AS blocking_amount,
   status, maker_id, checker_id, decided_at::text AS decided_at,
   consumed_by_issue_id, consumed_at::text AS consumed_at, created_at::text AS created_at`;

/** The same projection, aliased to `w.` for the queue JOIN. */
const COLUMNS_W =
  `w.id, w.student_id, w.lifecycle, w.reason, w.blocking_amount::text AS blocking_amount,
   w.status, w.maker_id, w.checker_id, w.decided_at::text AS decided_at,
   w.consumed_by_issue_id, w.consumed_at::text AS consumed_at, w.created_at::text AS created_at`;

/** Raise a PENDING waiver. Snapshots `blockingAmount` (what the checker is
 * approving). One pending-or-approved waiver per (student, lifecycle) is not
 * DB-enforced for pending (only `status='approved'` is unique), so the caller
 * should avoid stacking — but a duplicate pending is harmless (each decided
 * independently; the approved-unique index prevents two live approvals). */
export async function createWaiver(
  db: TenantQueryClient,
  scope: ClearanceScopeIds,
  input: {
    studentId: string;
    lifecycle: WaiverLifecycle;
    reason: string;
    blockingAmount: number;
    makerId: string;
  },
): Promise<ClearanceWaiverRow> {
  const rows = await db.queryObject<ClearanceWaiverRow>(
    `INSERT INTO student_clearance_waivers (
       organization_id, school_id, student_id, lifecycle, reason,
       blocking_amount, status, maker_id
     ) VALUES ($1,$2,$3,$4,$5,$6,'pending',$7)
     RETURNING ${COLUMNS}`,
    [
      scope.organizationId,
      scope.schoolId,
      input.studentId,
      input.lifecycle,
      input.reason,
      input.blockingAmount,
      input.makerId,
    ],
  );
  return rows[0]!;
}

/** The school's ACTIONABLE waiver queue for approvers: pending waivers (to
 * approve/reject) AND approved-but-un-consumed ones (to REVOKE when dues grew
 * past their cover — the deadlock escape, audit final P2). Pending first, then
 * approved, newest within each. JOINs the student's display name so the CHECKER
 * sees WHOSE exit they are clearing (audit slice-4 P2 — a maker-checker control
 * must not decide blind). LEFT JOIN so a waiver whose student row is missing
 * still surfaces (name null). */
export async function listPendingWaivers(
  db: TenantQueryClient,
  scope: ClearanceScopeIds,
  limit: number,
): Promise<ClearanceWaiverRow[]> {
  return await db.queryObject<ClearanceWaiverRow>(
    `SELECT ${COLUMNS_W}, s.display_name AS student_name
       FROM student_clearance_waivers w
       LEFT JOIN students s ON s.id = w.student_id
      WHERE w.organization_id = $1 AND w.school_id = $2
        AND (w.status = 'pending'
             OR (w.status = 'approved' AND w.consumed_by_issue_id IS NULL))
      ORDER BY CASE w.status WHEN 'pending' THEN 0 ELSE 1 END, w.created_at DESC
      LIMIT $3`,
    [scope.organizationId, scope.schoolId, limit],
  );
}

/**
 * Decide a pending waiver. Separation of duties: the checker can NEVER be the
 * maker (SELF_APPROVE_DENIED). The decision is CLAIMED via a status='pending'-
 * guarded UPDATE (a lost race → ALREADY_DECIDED, never a double approval; the
 * approved-unique index also backstops it). Approve → 'approved'; reject →
 * 'rejected'.
 */
export async function decideWaiver(
  db: TenantQueryClient,
  scope: ClearanceScopeIds,
  waiverId: string,
  checkerId: string,
  approve: boolean,
): Promise<ClearanceWaiverRow> {
  const pending = await db.queryObject<ClearanceWaiverRow>(
    `SELECT ${COLUMNS}
       FROM student_clearance_waivers
      WHERE organization_id = $1 AND school_id = $2 AND id = $3 AND status = 'pending'
      LIMIT 1`,
    [scope.organizationId, scope.schoolId, waiverId],
  );
  const row = pending[0];
  if (!row) {
    throw new ClearanceWaiverError("WAIVER_NOT_FOUND", "No pending waiver with that id");
  }
  // SoD: the requester can never decide their own waiver.
  if (checkerId !== "" && row.maker_id === checkerId) {
    throw new ClearanceWaiverError(
      "SELF_APPROVE_DENIED",
      "You cannot approve or reject a clearance waiver you raised",
      403,
    );
  }
  let claimed: ClearanceWaiverRow[];
  try {
    claimed = await db.queryObject<ClearanceWaiverRow>(
      `UPDATE student_clearance_waivers
          SET status = $4, checker_id = $5, decided_at = timezone('utc', now()),
              updated_at = timezone('utc', now())
        WHERE organization_id = $1 AND school_id = $2 AND id = $3 AND status = 'pending'
        RETURNING ${COLUMNS}`,
      [scope.organizationId, scope.schoolId, waiverId, approve ? "approved" : "rejected", checkerId],
    );
  } catch (err) {
    // Approving a second waiver while one is already approved for this
    // (student, lifecycle) trips uq_clearance_waivers_active — surface the
    // one-active-approval invariant as a clean 409, not a raw 500.
    const msg = err instanceof Error ? err.message : String(err);
    if (msg.includes("uq_clearance_waivers_active") || msg.includes("duplicate key")) {
      throw new ClearanceWaiverError(
        "WAIVER_ACTIVE_EXISTS",
        "An approved waiver already exists for this student — decide or consume it first",
        409,
      );
    }
    throw err;
  }
  const decided = claimed[0];
  if (!decided) {
    throw new ClearanceWaiverError(
      "WAIVER_ALREADY_DECIDED",
      "This waiver was already decided by another approver",
      409,
    );
  }
  return decided;
}

/**
 * Revoke an APPROVED, un-consumed waiver (checker action). This is the escape
 * from the deadlock (audit final P2): once a waiver is approved, dues can grow
 * past its snapshot so it no longer covers — the gate correctly refuses it, but
 * the one-approved-per-student unique index then blocks approving a fresh,
 * larger waiver. Revoking the stale approval (approved -> rejected) frees the
 * slot so a corrective waiver can be raised and approved. Status-guarded so a
 * waiver already consumed by an issued TC can never be revoked out from under it.
 */
export async function revokeApprovedWaiver(
  db: TenantQueryClient,
  scope: ClearanceScopeIds,
  waiverId: string,
  checkerId: string,
): Promise<ClearanceWaiverRow> {
  const rows = await db.queryObject<ClearanceWaiverRow>(
    `UPDATE student_clearance_waivers
        SET status = 'rejected', checker_id = $4, decided_at = timezone('utc', now()),
            updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3 AND status = 'approved'
      RETURNING ${COLUMNS}`,
    [scope.organizationId, scope.schoolId, waiverId, checkerId],
  );
  const row = rows[0];
  if (!row) {
    throw new ClearanceWaiverError(
      "WAIVER_NOT_REVOCABLE",
      "No approved (un-consumed) waiver with that id to revoke",
    );
  }
  return row;
}

/**
 * The gate lookup: the single active APPROVED, un-consumed waiver for
 * (student, lifecycle), or null. The partial unique index guarantees at most
 * one. Returns the snapshotted blocking_amount so the gate can enforce that the
 * waiver still COVERS the current dues (dues may not have grown past it).
 */
export async function findActiveWaiver(
  db: TenantQueryClient,
  scope: ClearanceScopeIds,
  studentId: string,
  lifecycle: WaiverLifecycle,
): Promise<ClearanceWaiverRow | null> {
  const rows = await db.queryObject<ClearanceWaiverRow>(
    `SELECT ${COLUMNS}
       FROM student_clearance_waivers
      WHERE organization_id = $1 AND school_id = $2
        AND student_id = $3 AND lifecycle = $4 AND status = 'approved'
      LIMIT 1`,
    [scope.organizationId, scope.schoolId, studentId, lifecycle],
  );
  return rows[0] ?? null;
}

/**
 * CONSUME the active approved waiver when its lifecycle event issues (single
 * use). Guarded on status='approved' so a concurrent second issuance can't
 * reuse it. Returns the consumed row, or null if nothing was approved to
 * consume (caller proceeds — the gate cleared without a waiver).
 */
export async function consumeWaiver(
  db: TenantQueryClient,
  scope: ClearanceScopeIds,
  studentId: string,
  lifecycle: WaiverLifecycle,
  // The TC issue that consumed it, or null when a non-TC exit (the raw status
  // endpoint transferring the student) consumes it — the row is still marked
  // single-use spent; consumed_by_issue_id is a nullable FK.
  issueId: string | null,
): Promise<ClearanceWaiverRow | null> {
  const rows = await db.queryObject<ClearanceWaiverRow>(
    `UPDATE student_clearance_waivers
        SET status = 'consumed', consumed_by_issue_id = $5,
            consumed_at = timezone('utc', now()), updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2
        AND student_id = $3 AND lifecycle = $4 AND status = 'approved'
      RETURNING ${COLUMNS}`,
    [scope.organizationId, scope.schoolId, studentId, lifecycle, issueId],
  );
  return rows[0] ?? null;
}
