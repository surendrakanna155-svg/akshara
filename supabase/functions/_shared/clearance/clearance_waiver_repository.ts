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

/** The school's PENDING waiver queue for approvers (newest first). */
export async function listPendingWaivers(
  db: TenantQueryClient,
  scope: ClearanceScopeIds,
  limit: number,
): Promise<ClearanceWaiverRow[]> {
  return await db.queryObject<ClearanceWaiverRow>(
    `SELECT ${COLUMNS}
       FROM student_clearance_waivers
      WHERE organization_id = $1 AND school_id = $2 AND status = 'pending'
      ORDER BY created_at DESC
      LIMIT $3`,
    [scope.organizationId, scope.schoolId, limit],
  );
}

/** A student's waivers for a lifecycle (newest first) — for the report/UI. */
export async function listWaiversForStudent(
  db: TenantQueryClient,
  scope: ClearanceScopeIds,
  studentId: string,
  lifecycle: WaiverLifecycle,
): Promise<ClearanceWaiverRow[]> {
  return await db.queryObject<ClearanceWaiverRow>(
    `SELECT ${COLUMNS}
       FROM student_clearance_waivers
      WHERE organization_id = $1 AND school_id = $2
        AND student_id = $3 AND lifecycle = $4
      ORDER BY created_at DESC
      LIMIT 20`,
    [scope.organizationId, scope.schoolId, studentId, lifecycle],
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
  const claimed = await db.queryObject<ClearanceWaiverRow>(
    `UPDATE student_clearance_waivers
        SET status = $4, checker_id = $5, decided_at = timezone('utc', now()),
            updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3 AND status = 'pending'
      RETURNING ${COLUMNS}`,
    [scope.organizationId, scope.schoolId, waiverId, approve ? "approved" : "rejected", checkerId],
  );
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
  issueId: string,
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
