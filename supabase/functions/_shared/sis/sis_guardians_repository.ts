import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * PRA-P1-01 / PRA-P1-02 (S2) — write path for a student's guardian links.
 *
 * `student_guardians` was, until this change, only ever INSERTed (at admission
 * and at onboarding import) and never mutated afterwards. There was therefore no
 * way to add a SECOND guardian to an existing student (PRA-P1-01) nor to unlink
 * a guardian (PRA-P1-02). These repository functions are that write path. They
 * are org + school + student scoped and fully parameterized; the parent-scope
 * auth resolution (and a companion RLS migration, written separately) already
 * filters `status = 'active'`, so flipping a link to `inactive` cleanly removes a
 * parent's access without deleting the historical row.
 */

/** One guardian-link row as returned by the write/list queries here. */
export interface GuardianLinkRow {
  id: string;
  student_id: string;
  guardian_user_id: string;
  relationship: string;
  is_primary: boolean;
  status: string;
}

export interface AddGuardianLinkOptions {
  relationship?: string;
  isPrimary?: boolean;
}

/**
 * PRA-P1-02 (S2) — raised when a deactivate targets a link that is already
 * inactive or was never created (the terminal UPDATE matched 0 rows). The
 * handler maps this to 404.
 */
export class GuardianLinkNotFoundError extends Error {
  readonly studentId: string;
  readonly guardianUserId: string;
  constructor(studentId: string, guardianUserId: string) {
    super(
      `No active guardian link for student ${studentId} and guardian ${guardianUserId}`,
    );
    this.name = "GuardianLinkNotFoundError";
    this.studentId = studentId;
    this.guardianUserId = guardianUserId;
  }
}

/**
 * PRA-P1-02 (S2) — raised when a deactivate would remove a student's LAST active
 * guardian. A student must never be left with zero contactable guardians, so the
 * write is refused (the handler maps this to 409).
 */
export class LastGuardianError extends Error {
  readonly studentId: string;
  readonly guardianUserId: string;
  constructor(studentId: string, guardianUserId: string) {
    super(
      `Cannot remove the last active guardian of student ${studentId}; ` +
        `a student must always have at least one active guardian`,
    );
    this.name = "LastGuardianError";
    this.studentId = studentId;
    this.guardianUserId = guardianUserId;
  }
}

/**
 * PRA-P1-01 (S2) — add (or re-activate) a guardian link for a student.
 *
 * Upserts on the `(student_id, guardian_user_id)` unique key so re-linking a
 * previously-unlinked guardian flips the same row back to `active` (rather than
 * failing the unique constraint or duplicating history). The INSERT column list
 * and conflict target mirror `onboarding_user_provisioning.linkStudentGuardian`.
 *
 * Single-primary invariant: when `isPrimary` is requested, every OTHER active
 * link for this student is demoted FIRST, so the student never ends up with two
 * active primaries. A second guardian defaults to `isPrimary = false` and never
 * steals primacy from the existing one.
 */
export async function addGuardianLink(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  guardianUserId: string,
  options: AddGuardianLinkOptions = {},
): Promise<GuardianLinkRow> {
  const relationship = (options.relationship ?? "guardian").trim() || "guardian";
  const isPrimary = options.isPrimary === true;

  // Single-primary invariant — demote this student's OTHER active links before
  // promoting the incoming one (excludes the incoming guardian so a re-add as
  // primary is a no-op on itself).
  if (isPrimary) {
    await db.queryObject(
      `UPDATE student_guardians
          SET is_primary = false
        WHERE organization_id = $1
          AND school_id = $2
          AND student_id = $3
          AND guardian_user_id <> $4
          AND status = 'active'`,
      [organizationId, schoolId, studentId, guardianUserId],
    );
  }

  const rows = await db.queryObject<GuardianLinkRow>(
    `INSERT INTO student_guardians (
       organization_id, school_id, student_id, guardian_user_id,
       relationship, is_primary, status
     ) VALUES ($1, $2, $3, $4, $5, $6, 'active')
     ON CONFLICT (student_id, guardian_user_id)
     DO UPDATE SET status = 'active',
                   relationship = EXCLUDED.relationship,
                   is_primary = EXCLUDED.is_primary
     RETURNING id, student_id, guardian_user_id, relationship, is_primary, status`,
    [organizationId, schoolId, studentId, guardianUserId, relationship, isPrimary],
  );
  return rows[0]!;
}

/**
 * PRA-P1-02 (S2) — unlink a guardian by flipping its link to `status='inactive'`
 * (never a hard delete — the row is kept for history, and the RLS active-link
 * clause removes the parent's access).
 *
 * Guards, in order:
 *  - the target must currently be an ACTIVE link for the student, else
 *    {@link GuardianLinkNotFoundError} (already inactive / never linked);
 *  - it must NOT be the student's ONLY active link, else
 *    {@link LastGuardianError} — a student must always keep one contactable
 *    guardian.
 *
 * The terminal UPDATE carries `AND status='active'` so a concurrent
 * double-deactivate writes once; a 0-row result (lost race) is reported as
 * not-found rather than silently succeeding.
 */
export async function deactivateGuardianLink(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  guardianUserId: string,
): Promise<string> {
  // Count the student's active links first (last-guardian guard).
  const active = await db.queryObject<{ guardian_user_id: string }>(
    `SELECT guardian_user_id
       FROM student_guardians
      WHERE organization_id = $1
        AND school_id = $2
        AND student_id = $3
        AND status = 'active'`,
    [organizationId, schoolId, studentId],
  );

  const targetIsActive = active.some((r) => r.guardian_user_id === guardianUserId);
  if (!targetIsActive) {
    // Nothing active to deactivate — already-inactive or never linked.
    throw new GuardianLinkNotFoundError(studentId, guardianUserId);
  }
  if (active.length <= 1) {
    // The target is active AND it is the sole active link — refuse.
    throw new LastGuardianError(studentId, guardianUserId);
  }

  const rows = await db.queryObject<{ id: string }>(
    `UPDATE student_guardians
        SET status = 'inactive'
      WHERE organization_id = $1
        AND school_id = $2
        AND student_id = $3
        AND guardian_user_id = $4
        AND status = 'active'
      RETURNING id`,
    [organizationId, schoolId, studentId, guardianUserId],
  );
  if (rows.length === 0) {
    // Lost a race with a concurrent deactivate — treat as not-found.
    throw new GuardianLinkNotFoundError(studentId, guardianUserId);
  }
  return rows[0]!.id;
}

/**
 * PRA-P1-01 / PRA-P1-02 (S2) — list ALL of a student's guardian links (active
 * and inactive), primary first. Used for the write-handler response shape and by
 * the repository tests to assert post-mutation state.
 */
export async function listGuardianLinks(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<GuardianLinkRow[]> {
  return await db.queryObject<GuardianLinkRow>(
    `SELECT id, student_id, guardian_user_id, relationship, is_primary, status
       FROM student_guardians
      WHERE organization_id = $1
        AND school_id = $2
        AND student_id = $3
      ORDER BY is_primary DESC, created_at ASC`,
    [organizationId, schoolId, studentId],
  );
}
