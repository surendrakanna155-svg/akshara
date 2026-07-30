import type { TenantQueryClient } from "../tenant_db.ts";
import {
  normalizeAcademicYearLabel,
  resolveAcademicPlacement,
  type PlacementInput,
} from "../academic/academic_catalog_resolver.ts";
import type {
  PaginationParams,
  PaginationResult,
} from "../finance/finance_structures_repository.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";

export interface EnrollmentListFilters {
  academicYear?: string;
  className?: string;
  sectionName?: string;
  studentId?: string;
  isCurrent?: boolean;
}

export interface EnrollmentListRow {
  enrollment_id: string;
  student_id: string;
  student_code: string;
  student_name: string;
  academic_year: string;
  academic_year_id: string | null;
  class_name: string;
  class_id: string | null;
  section_name: string | null;
  section_id: string | null;
  roll_number: string | null;
  is_current: boolean;
  created_at: string;
  updated_at: string;
}

export interface EnrollmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  academic_year: string;
  academic_year_id: string | null;
  class_name: string;
  class_id: string | null;
  section_name: string | null;
  section_id: string | null;
  roll_number: string | null;
  is_current: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateEnrollmentInput {
  studentId: string;
  academicYear: string;
  academicYearId?: string | null;
  className: string;
  classId?: string | null;
  sectionName?: string | null;
  sectionId?: string | null;
  rollNumber?: string | null;
  isCurrent?: boolean;
  createdBy: string;
}

export interface UpdateEnrollmentInput {
  academicYear?: string;
  academicYearId?: string | null;
  className?: string;
  classId?: string | null;
  sectionName?: string | null;
  sectionId?: string | null;
  rollNumber?: string | null;
  isCurrent?: boolean;
}

export class EnrollmentNotFoundError extends Error {
  constructor(id: string) {
    super(`Enrollment not found: ${id}`);
    this.name = "EnrollmentNotFoundError";
  }
}

export class DuplicateEnrollmentError extends Error {
  constructor(studentId: string, academicYear: string) {
    super(`Enrollment already exists for student ${studentId} in ${academicYear}`);
    this.name = "DuplicateEnrollmentError";
  }
}

/**
 * ICA-E1 — raised when a concurrent enroll/promote for the SAME student already
 * committed the single current placement first. The clear-then-write path
 * (clearCurrentEnrollmentsForStudent + INSERT/UPDATE) is a read-then-write with
 * no row lock, so under READ COMMITTED two transactions can each try to make a
 * row current. The DB partial-unique index sis_student_enrollments_one_current_uq
 * converts that race into a 23505 for the losing writer; this repository maps it
 * to a clean, retryable conflict instead of a raw 500 so the caller can re-read
 * and retry rather than leaving two is_current=true rows.
 *
 * It extends DuplicateEnrollmentError so a concurrency conflict is surfaced as an
 * HTTP 409 CONFLICT by the SAME handler mapping that already covers a per-year
 * duplicate (sis_enrollment_handlers.ts: `instanceof DuplicateEnrollmentError` →
 * 409) — no boundary edit is needed, and callers that special-case a duplicate
 * still see a conflict, not a 500. Sites that must distinguish the two (e.g. the
 * bulk-promote outcome mapping) MUST test for CurrentEnrollmentConflictError
 * BEFORE DuplicateEnrollmentError, since the subclass also matches the parent.
 */
export class CurrentEnrollmentConflictError extends DuplicateEnrollmentError {
  constructor(studentId: string) {
    // Parent sets a throwaway "already exists" message; overwrite it with the
    // concurrency/retry semantics that actually apply here.
    super(studentId, "the current academic year");
    this.name = "CurrentEnrollmentConflictError";
    this.message =
      `Current enrollment for student ${studentId} was changed concurrently; retry`;
  }
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

// Postgres unique_violation SQLSTATE. The sis_student_enrollments partial-unique
// index sis_student_enrollments_one_current_uq (WHERE is_current = true) and the
// UNIQUE (student_id, academic_year) constraint both raise this on a racing
// concurrent write that slips past the pre-insert read guards. Mirrors the
// transport/finance unique-violation backstops (transport_write_handlers.ts,
// finance_offline_reconcile double-credit guard).
const PG_UNIQUE_VIOLATION = "23505";
const ONE_CURRENT_ENROLLMENT_INDEX = "sis_student_enrollments_one_current_uq";

/**
 * If `error` is a Postgres unique_violation (23505), return the violated
 * constraint/index name ("" when the driver did not surface one); otherwise
 * return null. The deno-postgres driver exposes the SQLSTATE + constraint name on
 * `error.fields`; older shapes carry them at the top level, so both are checked.
 */
function uniqueViolationConstraint(error: unknown): string | null {
  if (typeof error !== "object" || error === null) return null;
  const e = error as {
    code?: unknown;
    constraint?: unknown;
    fields?: { code?: unknown; constraint?: unknown };
  };
  const code = e.code ?? e.fields?.code;
  if (code !== PG_UNIQUE_VIOLATION) return null;
  const constraint = e.constraint ?? e.fields?.constraint;
  return typeof constraint === "string" ? constraint : "";
}

/**
 * Map a unique_violation raised by the clear-then-write current-enrollment path
 * to a typed, caller-actionable error. `isCurrent` is whether THIS write was
 * setting the row current (only then can the single-current index fire):
 *   * sis_student_enrollments_one_current_uq → CurrentEnrollmentConflictError
 *   * (student_id, academic_year) uniqueness  → DuplicateEnrollmentError
 *   * unknown 23505 while making a row current → treat as the single-current race
 *     (a clean retryable conflict beats a raw 500)
 * Returns null when `error` is not a unique_violation, so the caller rethrows the
 * original (a genuine, unexpected failure must never be masked as a conflict).
 */
function mapEnrollmentUniqueViolation(
  error: unknown,
  studentId: string,
  academicYear: string,
  isCurrent: boolean,
): Error | null {
  const constraint = uniqueViolationConstraint(error);
  if (constraint === null) return null;
  if (constraint === ONE_CURRENT_ENROLLMENT_INDEX) {
    return new CurrentEnrollmentConflictError(studentId);
  }
  if (constraint.includes("academic_year")) {
    return new DuplicateEnrollmentError(studentId, academicYear);
  }
  return isCurrent
    ? new CurrentEnrollmentConflictError(studentId)
    : new DuplicateEnrollmentError(studentId, academicYear);
}

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

function listJoinSql(): string {
  return `FROM sis_student_enrollments se
  INNER JOIN students s
    ON s.id = se.student_id
   AND s.organization_id = se.organization_id
   AND s.school_id = se.school_id`;
}

function listFromSql(): string {
  return `SELECT
    se.id AS enrollment_id,
    se.student_id,
    s.student_code,
    s.display_name AS student_name,
    se.academic_year,
    se.academic_year_id,
    se.class_name,
    se.class_id,
    se.section_name,
    se.section_id,
    se.roll_number,
    se.is_current,
    se.created_at,
    se.updated_at
  ${listJoinSql()}`;
}

function listWhereSql(): string {
  return `WHERE se.organization_id = $1
    AND se.school_id = $2
    AND ($3::text IS NULL OR se.academic_year = $3)
    AND ($4::text IS NULL OR se.class_name = $4)
    AND ($5::text IS NULL OR se.section_name = $5)
    AND ($6::uuid IS NULL OR se.student_id = $6)
    AND ($7::boolean IS NULL OR se.is_current = $7)`;
}

function filterArgs(
  organizationId: string,
  schoolId: string,
  filters: EnrollmentListFilters,
): unknown[] {
  return [
    organizationId,
    schoolId,
    filters.academicYear ?? null,
    filters.className ?? null,
    filters.sectionName ?? null,
    filters.studentId ?? null,
    filters.isCurrent ?? null,
  ];
}

function toPlacementInput(input: {
  academicYear?: string;
  academicYearId?: string | null;
  className?: string;
  classId?: string | null;
  sectionName?: string | null;
  sectionId?: string | null;
}): PlacementInput {
  return {
    academicYear: input.academicYear,
    academicYearId: input.academicYearId,
    className: input.className,
    classId: input.classId,
    sectionName: input.sectionName,
    sectionId: input.sectionId,
  };
}

async function studentExists(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM students
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentId, organizationId, schoolId],
  );
  return rows.length > 0;
}

async function enrollmentExistsForYear(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  academicYear: string,
  excludeEnrollmentId?: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM sis_student_enrollments
     WHERE organization_id = $1 AND school_id = $2
       AND student_id = $3 AND academic_year = $4
       AND ($5::uuid IS NULL OR id <> $5)
     LIMIT 1`,
    [organizationId, schoolId, studentId, academicYear, excludeEnrollmentId ?? null],
  );
  return rows.length > 0;
}

export async function clearCurrentEnrollmentsForStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  exceptEnrollmentId?: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE sis_student_enrollments SET
      is_current = false,
      updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
       AND is_current = true
       AND ($4::uuid IS NULL OR id <> $4)`,
    [organizationId, schoolId, studentId, exceptEnrollmentId ?? null],
  );
}

async function getEnrollmentRow(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  enrollmentId: string,
): Promise<EnrollmentRow | null> {
  const rows = await db.queryObject<EnrollmentRow>(
    `SELECT * FROM sis_student_enrollments
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [enrollmentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

async function getEnrollmentListRow(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  enrollmentId: string,
): Promise<EnrollmentListRow | null> {
  const rows = await db.queryObject<EnrollmentListRow>(
    `${listFromSql()}
     WHERE se.id = $1 AND se.organization_id = $2 AND se.school_id = $3`,
    [enrollmentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function listEnrollments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: EnrollmentListFilters,
  pagination: PaginationParams,
): Promise<PaginationResult<EnrollmentListRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);
  const args = filterArgs(organizationId, schoolId, filters);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count
     ${listJoinSql()}
     ${listWhereSql()}`,
    args,
  );

  const items = await db.queryObject<EnrollmentListRow>(
    `${listFromSql()}
     ${listWhereSql()}
     ORDER BY se.is_current DESC, se.created_at DESC
     LIMIT $8 OFFSET $9`,
    [...args, limit, offset],
  );

  return {
    items,
    total,
    page: pagination.page,
    pageSize: limit,
    hasMore: offset + items.length < total,
  };
}

export async function createEnrollment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateEnrollmentInput,
): Promise<EnrollmentListRow> {
  const studentId = input.studentId.trim();
  if (!studentId) throw new ValidationError("studentId is required");

  if (!await studentExists(db, organizationId, schoolId, studentId)) {
    throw new StudentNotFoundError(studentId);
  }

  const placement = await resolveAcademicPlacement(
    { db, organizationId, schoolId },
    toPlacementInput(input),
    { mode: "full" },
  );

  const academicYear = placement.academicYear;
  const className = placement.className;
  if (!academicYear) throw new ValidationError("academicYear is required");
  if (!className) throw new ValidationError("className is required");

  if (await enrollmentExistsForYear(db, organizationId, schoolId, studentId, academicYear)) {
    throw new DuplicateEnrollmentError(studentId, academicYear);
  }

  const isCurrent = input.isCurrent ?? true;
  // Clear-then-insert is a read-then-write with no lock. The DB partial-unique
  // index sis_student_enrollments_one_current_uq (+ the per-year UNIQUE) turns a
  // racing concurrent enroll into a 23505 for the loser; catch it here and map it
  // to a typed, retryable conflict instead of letting it surface as a raw 500.
  let enrollmentId: string;
  try {
    if (isCurrent) {
      await clearCurrentEnrollmentsForStudent(db, organizationId, schoolId, studentId);
    }

    const insertRows = await db.queryObject<{ id: string }>(
      `INSERT INTO sis_student_enrollments (
        organization_id, school_id, student_id, academic_year, academic_year_id,
        class_name, class_id, section_name, section_id,
        roll_number, is_current, created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING id`,
      [
        organizationId,
        schoolId,
        studentId,
        academicYear,
        placement.academicYearId,
        className,
        placement.classId,
        placement.sectionName,
        placement.sectionId,
        input.rollNumber ?? null,
        isCurrent,
        input.createdBy,
      ],
    );
    enrollmentId = insertRows[0]!.id;
  } catch (error) {
    const mapped = mapEnrollmentUniqueViolation(error, studentId, academicYear, isCurrent);
    if (mapped) throw mapped;
    throw error;
  }

  const row = await getEnrollmentListRow(db, organizationId, schoolId, enrollmentId);
  if (!row) throw new EnrollmentNotFoundError(enrollmentId);
  return row;
}

export async function updateEnrollment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  enrollmentId: string,
  input: UpdateEnrollmentInput,
): Promise<EnrollmentListRow> {
  const existing = await getEnrollmentRow(db, organizationId, schoolId, enrollmentId);
  if (!existing) throw new EnrollmentNotFoundError(enrollmentId);

  const yearLabelProvided = input.academicYear !== undefined;
  const classLabelProvided = input.className !== undefined;
  const sectionLabelProvided = input.sectionName !== undefined;

  const mergedInput: PlacementInput = {
    academicYearId: input.academicYearId !== undefined
      ? input.academicYearId
      : (yearLabelProvided ? null : existing.academic_year_id),
    academicYear: yearLabelProvided ? input.academicYear : existing.academic_year,
    classId: input.classId !== undefined
      ? input.classId
      : (classLabelProvided || yearLabelProvided ? null : existing.class_id),
    className: classLabelProvided ? input.className : existing.class_name,
    sectionId: input.sectionId !== undefined
      ? input.sectionId
      : (sectionLabelProvided || classLabelProvided || yearLabelProvided
        ? null
        : existing.section_id),
    sectionName: sectionLabelProvided ? input.sectionName : existing.section_name,
  };

  const placement = await resolveAcademicPlacement(
    { db, organizationId, schoolId },
    mergedInput,
    { mode: "full" },
  );

  const academicYear = placement.academicYear;
  const className = placement.className;
  const sectionName = placement.sectionName;
  const rollNumber = input.rollNumber !== undefined
    ? input.rollNumber
    : existing.roll_number;
  const isCurrent = input.isCurrent ?? existing.is_current;

  if (!academicYear) throw new ValidationError("academicYear cannot be empty");
  if (!className) throw new ValidationError("className cannot be empty");

  if (academicYear !== existing.academic_year &&
    await enrollmentExistsForYear(
      db,
      organizationId,
      schoolId,
      existing.student_id,
      academicYear,
      enrollmentId,
    )) {
    throw new DuplicateEnrollmentError(existing.student_id, academicYear);
  }

  // Same race as createEnrollment: flipping this row current (after clearing the
  // prior one) can collide with a concurrent enroll/promote on the single-current
  // partial-unique index. Map the 23505 to a typed conflict rather than a 500.
  try {
    if (isCurrent) {
      await clearCurrentEnrollmentsForStudent(
        db,
        organizationId,
        schoolId,
        existing.student_id,
        enrollmentId,
      );
    }

    await db.queryObject(
      `UPDATE sis_student_enrollments SET
        academic_year = $1,
        academic_year_id = $2,
        class_name = $3,
        class_id = $4,
        section_name = $5,
        section_id = $6,
        roll_number = $7,
        is_current = $8,
        updated_at = timezone('utc', now())
       WHERE id = $9 AND organization_id = $10 AND school_id = $11`,
      [
        academicYear,
        placement.academicYearId,
        className,
        placement.classId,
        sectionName,
        placement.sectionId,
        rollNumber,
        isCurrent,
        enrollmentId,
        organizationId,
        schoolId,
      ],
    );
  } catch (error) {
    const mapped = mapEnrollmentUniqueViolation(
      error,
      existing.student_id,
      academicYear,
      isCurrent,
    );
    if (mapped) throw mapped;
    throw error;
  }

  const row = await getEnrollmentListRow(db, organizationId, schoolId, enrollmentId);
  if (!row) throw new EnrollmentNotFoundError(enrollmentId);
  return row;
}

// ─── WEB-005 (ERP-WT-005): registrar class-management bulk workflows ─────────
//
// These are pure EXECUTORS of UI-supplied targets (the roster UI makes every
// who/where decision) — no promotion-policy engine, so no owner policy call is
// needed. They compose the certified single-row primitives (createEnrollment /
// updateEnrollment, which already do student-exists + placement resolution +
// duplicate-guard + auto-clearing the prior current enrollment). Each row runs
// inside its own SAVEPOINT so one bad row can't abort the batch; the whole run
// is still one transaction (withTenantContext), so successful rows commit
// together and a failed row leaves NO partial residue. Returns a per-student
// outcome so the caller can report + re-run safely (idempotent: an already-
// promoted student is 'skipped_exists', not a hard error).

export interface PromotionTarget {
  studentId: string;
  academicYear: string;
  academicYearId?: string | null;
  className: string;
  classId?: string | null;
  sectionName?: string | null;
  sectionId?: string | null;
  rollNumber?: string | null;
}

export interface SectionMove {
  studentId: string;
  sectionName: string;
  rollNumber?: string | null;
}

export interface BulkOutcome {
  studentId: string;
  status: string;
  enrollmentId?: string;
  message?: string;
}

/** The current (is_current) enrollment id for a student, or null. */
export async function getCurrentEnrollmentId(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM sis_student_enrollments
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3 AND is_current = true
     ORDER BY created_at DESC LIMIT 1`,
    [organizationId, schoolId, studentId],
  );
  return rows[0]?.id ?? null;
}

/**
 * Bulk year-end promotion: for each target, create the next-year enrollment
 * (auto-clearing the old current one). Per-student savepoint isolation.
 */
export async function promoteStudentsBulk(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  targets: PromotionTarget[],
  createdBy: string,
): Promise<BulkOutcome[]> {
  const outcomes: BulkOutcome[] = [];
  let i = 0;
  for (const t of targets) {
    const sp = `promo_${i++}`;
    await db.queryObject(`SAVEPOINT ${sp}`);
    try {
      const created = await createEnrollment(db, organizationId, schoolId, {
        studentId: t.studentId,
        academicYear: t.academicYear,
        academicYearId: t.academicYearId ?? null,
        className: t.className,
        classId: t.classId ?? null,
        sectionName: t.sectionName ?? null,
        sectionId: t.sectionId ?? null,
        rollNumber: t.rollNumber ?? null,
        isCurrent: true,
        createdBy,
      });
      await db.queryObject(`RELEASE SAVEPOINT ${sp}`);
      outcomes.push({ studentId: t.studentId, status: "promoted", enrollmentId: created.enrollment_id });
    } catch (error) {
      await db.queryObject(`ROLLBACK TO SAVEPOINT ${sp}`);
      await db.queryObject(`RELEASE SAVEPOINT ${sp}`);
      if (error instanceof CurrentEnrollmentConflictError) {
        // MUST precede the DuplicateEnrollmentError branch — this is a subclass.
        // Concurrent enroll/promote for this student won the single-current race;
        // report a retryable conflict (per-student savepoint already rolled back).
        outcomes.push({ studentId: t.studentId, status: "conflict", message: error.message });
      } else if (error instanceof DuplicateEnrollmentError) {
        outcomes.push({ studentId: t.studentId, status: "skipped_exists", message: error.message });
      } else if (error instanceof StudentNotFoundError) {
        outcomes.push({ studentId: t.studentId, status: "not_found", message: error.message });
      } else {
        outcomes.push({
          studentId: t.studentId,
          status: "error",
          message: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }
  return outcomes;
}

/**
 * Bulk section move (reshuffle / section-balance): re-section each student's
 * CURRENT enrollment via the placement-resolving updateEnrollment primitive
 * (so section_id stays consistent with the new label). Per-student savepoint.
 */
export async function applySectionMovesBulk(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  moves: SectionMove[],
): Promise<BulkOutcome[]> {
  const outcomes: BulkOutcome[] = [];
  let i = 0;
  for (const m of moves) {
    const sp = `reshuffle_${i++}`;
    await db.queryObject(`SAVEPOINT ${sp}`);
    try {
      const currentId = await getCurrentEnrollmentId(db, organizationId, schoolId, m.studentId);
      if (!currentId) {
        await db.queryObject(`ROLLBACK TO SAVEPOINT ${sp}`);
        await db.queryObject(`RELEASE SAVEPOINT ${sp}`);
        outcomes.push({ studentId: m.studentId, status: "no_current_enrollment" });
        continue;
      }
      const updated = await updateEnrollment(db, organizationId, schoolId, currentId, {
        sectionName: m.sectionName,
        rollNumber: m.rollNumber ?? undefined,
      });
      await db.queryObject(`RELEASE SAVEPOINT ${sp}`);
      outcomes.push({ studentId: m.studentId, status: "moved", enrollmentId: updated.enrollment_id });
    } catch (error) {
      await db.queryObject(`ROLLBACK TO SAVEPOINT ${sp}`);
      await db.queryObject(`RELEASE SAVEPOINT ${sp}`);
      outcomes.push({
        studentId: m.studentId,
        status: "error",
        message: error instanceof Error ? error.message : String(error),
      });
    }
  }
  return outcomes;
}

/** Normalize year label for duplicate checks (matches Flutter). */
export { normalizeAcademicYearLabel };

/** Probe: non-school scopes denied enrollment API reads. */
export const SIS_ENROLLMENTS_API_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM sis_student_enrollments se
  INNER JOIN students s ON s.id = se.student_id
`;

/** Probe: cross-school enrollment update target visibility. */
export const SIS_ENROLLMENT_UPDATE_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM sis_student_enrollments
  WHERE id = $1
`;
