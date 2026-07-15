import { getFeeHandoffById } from "../admissions/admissions_handoffs_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { getAcademicYear } from "../academic/academic_years_repository.ts";
import { createAnnualInvoice, getInvoiceByAssignmentId } from "./finance_invoices_repository.ts";
import type { FinanceInvoiceRow } from "./finance_invoices_repository.ts";
import type { PaginationParams, PaginationResult } from "./finance_structures_repository.ts";
import { getFinanceSettingValue } from "./finance_settings_repository.ts";
import {
  computeFeeProration,
  DEFAULT_FEE_PRORATION_POLICY,
  FEE_PRORATION_SETTING,
  FeeProrationOverrideReasonRequiredError,
  type FeeProrationPolicy,
  type FeeProrationYearBounds,
  parseFeeProrationPolicy,
} from "./finance_fee_proration.ts";

export { FeeProrationOverrideReasonRequiredError } from "./finance_fee_proration.ts";
export type { FeeProrationPolicy } from "./finance_fee_proration.ts";

export interface FinanceFeeAssignmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  fee_structure_id: string;
  academic_year: string;
  assignment_status: string;
  assigned_by: string;
  assigned_at: string;
  created_at: string;
  updated_at: string;
  // Cap 73 (owner decision #5) — mid-year admission fee proration, recorded
  // durably per-assignment so the applied policy can be understood later, not
  // just at the moment of assignment.
  proration_policy: string;
  proration_basis: string;
  proration_total_months: number | null;
  proration_months_charged: number | null;
  proration_reference_date: string | null;
  proration_annual_amount: string | null;
  proration_charged_amount: string | null;
  proration_fallback_reason: string | null;
  proration_is_override: boolean;
  proration_override_reason: string | null;
  proration_overridden_by: string | null;
}

export interface FinanceStudentAccountRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  fee_assignment_id: string;
  academic_year: string;
  total_fee: string;
  amount_paid: string;
  outstanding_amount: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface AssignmentWithAccount {
  assignment: FinanceFeeAssignmentRow;
  account: FinanceStudentAccountRow;
  invoice: FinanceInvoiceRow;
  feeStructureName?: string;
  studentName?: string;
  admissionNumber?: string;
  classLabel?: string;
}

export interface AssignFeeStructureInput {
  studentId: string;
  feeStructureId: string;
  academicYear: string;
  assignedBy: string;
  // Cap 73 — the admission/assignment reference date proration is computed
  // against, 'YYYY-MM-DD'. Defaults to today when omitted (e.g. a same-day
  // walk-in assignment; historically that was the implicit assumption for
  // every assignment).
  admissionDate?: string;
  // An authorized user's explicit, per-assignment override of the school's
  // configured policy (e.g. a documented exception for one student).
  // `prorationOverrideReason` is REQUIRED whenever this is set — enforced
  // below — and both are recorded on the assignment row for audit evidence,
  // alongside `assignedBy` as the acting/overriding user and `assigned_at` as
  // the timestamp.
  prorationPolicyOverride?: FeeProrationPolicy;
  prorationOverrideReason?: string;
}

export class DuplicateAssignmentError extends Error {
  constructor() {
    super("Fee assignment already exists for student, structure, and academic year");
    this.name = "DuplicateAssignmentError";
  }
}

export class DuplicateStudentAccountError extends Error {
  constructor() {
    super("Student account already exists for academic year");
    this.name = "DuplicateStudentAccountError";
  }
}

export class HandoffNotReadyError extends Error {
  constructor(status: string) {
    super(`Handoff not ready for assignment (status: ${status})`);
    this.name = "HandoffNotReadyError";
  }
}

// Cap 67 — a bulk/class-wide assignment was called without an explicit
// studentIds[] and the target fee structure has no class/section binding to
// auto-resolve students from.
export class FeeStructureNotBoundError extends Error {
  constructor(feeStructureId: string) {
    super(
      `Fee structure has no class/section binding to auto-resolve students from: ${feeStructureId}`,
    );
    this.name = "FeeStructureNotBoundError";
  }
}

const ASSIGNABLE_HANDOFF_STATUSES = new Set(["pending", "sent_to_finance"]);

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

/** 'YYYY-MM-DD' for today (UTC) — the default proration reference date. */
function todayIsoDate(): string {
  return new Date().toISOString().slice(0, 10);
}

async function sumStructureFees(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  feeStructureId: string,
): Promise<number> {
  const rows = await db.queryObject<{ total: string }>(
    `SELECT COALESCE(SUM(amount), 0)::text AS total
     FROM finance_fee_structure_items
     WHERE fee_structure_id = $1 AND organization_id = $2 AND school_id = $3`,
    [feeStructureId, organizationId, schoolId],
  );
  return parseFloat(rows[0]?.total ?? "0");
}

interface FeeStructureForAssignment {
  name: string;
  academic_year: string;
  academic_year_id: string | null;
  class_id: string | null;
  section_id: string | null;
}

async function ensureFeeStructureExists(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  feeStructureId: string,
): Promise<FeeStructureForAssignment> {
  const rows = await db.queryObject<FeeStructureForAssignment>(
    `SELECT name, academic_year, academic_year_id, class_id, section_id
     FROM finance_fee_structures
     WHERE id = $1 AND organization_id = $2 AND school_id = $3 AND status = 'active'`,
    [feeStructureId, organizationId, schoolId],
  );
  const structure = rows[0];
  if (!structure) {
    throw new Error(`Fee structure not found or inactive: ${feeStructureId}`);
  }
  return structure;
}

/**
 * Cap 73 — resolves a fee structure's academic year to real calendar bounds
 * for proration. Returns null (never throws) when the structure has no
 * academic_year_id or the referenced year can't be found — the caller treats
 * that as "can't prorate, fall back to full_annual" rather than failing the
 * assignment over a data gap that predates this feature.
 */
async function resolveProrationYearBounds(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  academicYearId: string | null,
): Promise<FeeProrationYearBounds | null> {
  if (!academicYearId) return null;
  const year = await getAcademicYear(db, organizationId, schoolId, academicYearId);
  if (!year) return null;
  return { startDate: year.start_date, endDate: year.end_date };
}

/**
 * Cap 67 — resolves the student ids a bound fee structure's class/section
 * covers, for the bulk-assign endpoint's auto-resolve path. Only CURRENT
 * enrollments of ACTIVE students are included (a stale/superseded enrollment
 * row, or an alumni/transferred/inactive student, must not receive a fresh
 * fee assignment just because they once sat in the bound class).
 */
export async function resolveStudentIdsForBoundStructure(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  feeStructureId: string,
): Promise<string[]> {
  const rows = await db.queryObject<{ class_id: string | null; section_id: string | null }>(
    `SELECT class_id, section_id FROM finance_fee_structures
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [feeStructureId, organizationId, schoolId],
  );
  const structure = rows[0];
  if (!structure) {
    throw new Error(`Fee structure not found: ${feeStructureId}`);
  }
  if (!structure.class_id) {
    throw new FeeStructureNotBoundError(feeStructureId);
  }

  const studentRows = await db.queryObject<{ student_id: string }>(
    `SELECT DISTINCT se.student_id
       FROM sis_student_enrollments se
       INNER JOIN students s
         ON s.id = se.student_id
        AND s.organization_id = se.organization_id
        AND s.school_id = se.school_id
      WHERE se.organization_id = $1 AND se.school_id = $2
        AND se.class_id = $3
        AND ($4::uuid IS NULL OR se.section_id = $4)
        AND se.is_current = true
        AND s.status = 'active'`,
    [organizationId, schoolId, structure.class_id, structure.section_id],
  );
  return studentRows.map((r) => r.student_id);
}

async function createAssignmentAndAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: AssignFeeStructureInput,
): Promise<AssignmentWithAccount> {
  const structure = await ensureFeeStructureExists(db, organizationId, schoolId, input.feeStructureId);

  const duplicate = await db.queryObject<{ id: string }>(
    `SELECT id FROM finance_fee_assignments
     WHERE student_id = $1 AND fee_structure_id = $2 AND academic_year = $3
       AND organization_id = $4 AND school_id = $5`,
    [
      input.studentId,
      input.feeStructureId,
      input.academicYear,
      organizationId,
      schoolId,
    ],
  );
  if (duplicate[0]) {
    throw new DuplicateAssignmentError();
  }

  // Cap 73 (owner decision #5) — mid-year admission fee proration. The
  // configured policy comes from finance_settings (reusing FIN-6's home
  // exactly); an authorized caller may override it for THIS ONE assignment,
  // but only with a reason (audit evidence — see FeeProrationOverrideReasonRequiredError).
  if (input.prorationPolicyOverride && !input.prorationOverrideReason?.trim()) {
    throw new FeeProrationOverrideReasonRequiredError();
  }
  const configuredPolicy = parseFeeProrationPolicy(
    await getFinanceSettingValue(
      db,
      organizationId,
      schoolId,
      FEE_PRORATION_SETTING.sectionId,
      FEE_PRORATION_SETTING.itemId,
      DEFAULT_FEE_PRORATION_POLICY,
    ),
  );
  const isOverride = input.prorationPolicyOverride != null &&
    input.prorationPolicyOverride !== configuredPolicy;
  const effectivePolicy = input.prorationPolicyOverride ?? configuredPolicy;
  const yearBounds = await resolveProrationYearBounds(
    db,
    organizationId,
    schoolId,
    structure.academic_year_id,
  );
  const referenceDate = input.admissionDate?.trim() || todayIsoDate();

  // TRN-9 (owner decision): a student's per-year finance account is a SHARED
  // container — tuition + transport (and any other structure) coexist as
  // MULTIPLE invoices under ONE finance_student_accounts row. So GET-OR-CREATE
  // the account instead of throwing on a pre-existing one: reuse the existing
  // account when the student already has one for this academic year, and only
  // create a fresh account when this is the student's first structure this year.
  // The per-(student, structure, year) UNIQUE on finance_fee_assignments (guarded
  // above) still makes assigning the SAME structure twice idempotent-by-rejection;
  // this change only unblocks assigning a DIFFERENT structure to a student who
  // already has an account. The account's aggregate money columns (total_fee /
  // amount_paid / outstanding_amount) are NOT re-derived here — each structure
  // raises its own invoice with its own outstanding, which stays authoritative.
  const existingAccount = await db.queryObject<FinanceStudentAccountRow>(
    `SELECT * FROM finance_student_accounts
     WHERE student_id = $1 AND academic_year = $2 AND organization_id = $3 AND school_id = $4`,
    [input.studentId, input.academicYear, organizationId, schoolId],
  );
  const reuseAccount = existingAccount[0] ?? null;

  const totalFee = await sumStructureFees(
    db,
    organizationId,
    schoolId,
    input.feeStructureId,
  );

  const proration = computeFeeProration({
    policy: effectivePolicy,
    annualAmount: totalFee,
    referenceDate,
    yearBounds,
    isOverride,
    overrideReason: input.prorationOverrideReason ?? null,
  });
  // The amount this assignment ACTUALLY charges — the annual total under
  // full_annual (unchanged existing behaviour), or the prorated tail-months
  // amount under prorate_from_admission_month. Every downstream money write
  // (account seed/bump, invoice total) uses THIS, never the raw annual total.
  const chargedTotal = proration.chargedAmount;

  const assignmentRows = await db.queryObject<FinanceFeeAssignmentRow>(
    `INSERT INTO finance_fee_assignments (
      organization_id, school_id, student_id, fee_structure_id,
      academic_year, assignment_status, assigned_by,
      proration_policy, proration_basis, proration_total_months,
      proration_months_charged, proration_reference_date,
      proration_annual_amount, proration_charged_amount,
      proration_fallback_reason, proration_is_override,
      proration_override_reason, proration_overridden_by
    ) VALUES (
      $1, $2, $3, $4, $5, 'active', $6,
      $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17
    )
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.studentId,
      input.feeStructureId,
      input.academicYear,
      input.assignedBy,
      proration.policy,
      proration.basis,
      proration.totalMonths,
      proration.monthsCharged,
      proration.referenceDate,
      proration.annualAmount,
      proration.chargedAmount,
      proration.fallbackReason,
      proration.isOverride,
      proration.overrideReason,
      proration.isOverride ? input.assignedBy : null,
    ],
  );

  const assignment = assignmentRows[0]!;

  // Get-or-create: reuse the student's existing per-year account when present,
  // otherwise open a new one seeded from THIS structure's CHARGED total (not
  // the raw annual total — a prorated assignment must never inflate the
  // account by months it isn't billing).
  const account = reuseAccount ?? (await db.queryObject<FinanceStudentAccountRow>(
    `INSERT INTO finance_student_accounts (
      organization_id, school_id, student_id, fee_assignment_id,
      academic_year, total_fee, amount_paid, outstanding_amount, status
    ) VALUES ($1, $2, $3, $4, $5, $6, 0, $6, 'open')
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.studentId,
      assignment.id,
      input.academicYear,
      chargedTotal,
    ],
  ))[0]!;

  const invoice = await createAnnualInvoice(db, organizationId, schoolId, {
    studentId: input.studentId,
    feeAssignmentId: assignment.id,
    academicYear: input.academicYear,
    totalAmount: chargedTotal,
    createdBy: input.assignedBy,
  });

  // When the per-year account is REUSED (a second/third structure for the same
  // student+year), fold THIS structure's total into the shared account container
  // so its aggregate columns stay authoritative: collections decrement
  // finance_student_accounts.outstanding_amount (finance_collections_repository),
  // and the dashboard + defaulters/recovery read it. Without this the account
  // would under-report the student's true dues by the new structure's amount and
  // a later collection against the new invoice would drive the account balance
  // wrong. A freshly-INSERTED account already carries this structure's total, so
  // only the reuse path needs the bump. amount_paid is untouched (new invoice = 0
  // paid); status re-opens because there is fresh outstanding.
  let effectiveAccount = account;
  if (reuseAccount) {
    const bumped = await db.queryObject<FinanceStudentAccountRow>(
      `UPDATE finance_student_accounts SET
         total_fee = total_fee + $1,
         outstanding_amount = outstanding_amount + $1,
         status = 'open',
         updated_at = timezone('utc', now())
       WHERE id = $2 AND organization_id = $3 AND school_id = $4
       RETURNING *`,
      [chargedTotal, reuseAccount.id, organizationId, schoolId],
    );
    effectiveAccount = bumped[0] ?? account;
  }

  return await enrichAssignmentWithAccount(
    db,
    organizationId,
    schoolId,
    assignment,
    effectiveAccount,
    invoice,
  );
}

export async function listAssignments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
): Promise<PaginationResult<FinanceFeeAssignmentRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM finance_fee_assignments
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<FinanceFeeAssignmentRow>(
    `SELECT * FROM finance_fee_assignments
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY assigned_at DESC
     LIMIT $3 OFFSET $4`,
    [organizationId, schoolId, limit, offset],
  );

  return {
    items,
    total,
    page: pagination.page,
    pageSize: limit,
    hasMore: offset + items.length < total,
  };
}

export async function getAssignment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  assignmentId: string,
): Promise<FinanceFeeAssignmentRow | null> {
  const rows = await db.queryObject<FinanceFeeAssignmentRow>(
    `SELECT * FROM finance_fee_assignments
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [assignmentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function assignFeeStructure(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: AssignFeeStructureInput,
): Promise<AssignmentWithAccount> {
  return await createAssignmentAndAccount(db, organizationId, schoolId, input);
}

// ─── Bulk/class-wide assignment (PRC-A gap fix) ────────────────────────────
// Every assignment used to be one student at a time via the admissions-handoff
// queue (assignFromHandoff) or a single direct assign (assignFeeStructure) — a
// real school assigning a fee structure to a whole class had no way to do it
// without repeating the single-assign flow per student.

// Postgres unique_violation SQLSTATE — finance_fee_assignments has
// UNIQUE(student_id, fee_structure_id, academic_year); createAssignmentAndAccount
// already app-level-checks for a duplicate BEFORE inserting, but that check is
// a plain SELECT-then-INSERT with a TOCTOU gap, so a race (e.g. a second,
// concurrent bulk call over an overlapping student set) can still surface as a
// real constraint violation on the INSERT. Mirrors the same local-copy idiom
// used in transport_write_handlers.ts / admissions_repository.ts /
// pilot_operations_repository.ts (no shared helper exists for this).
const PG_UNIQUE_VIOLATION = "23505";

function isUniqueViolation(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const code = (error as { code?: unknown; fields?: { code?: unknown } }).code ??
    (error as { fields?: { code?: unknown } }).fields?.code;
  return code === PG_UNIQUE_VIOLATION;
}

export interface BulkAssignFeeStructureInput {
  feeStructureId: string;
  academicYear: string;
  studentIds: string[];
  assignedBy: string;
  // Cap 73 — applied uniformly to every student in the batch (a class-wide
  // assignment has one reference date/policy decision for the whole call;
  // per-student admission dates aren't tracked at this call site).
  admissionDate?: string;
  prorationPolicyOverride?: FeeProrationPolicy;
  prorationOverrideReason?: string;
}

export interface BulkAssignSkipped {
  studentId: string;
  reason: string;
}

export interface BulkAssignResult {
  assigned: AssignmentWithAccount[];
  skipped: BulkAssignSkipped[];
  total: number;
}

/**
 * Bulk/class-wide fee-structure assignment. Reuses `assignFeeStructure`
 * UNCHANGED per student — identical invoice/account math, including the
 * TRN-9 get-or-create per-year account — inside the SAME transaction the
 * caller opened via `withTenantContext`, so the whole batch commits or rolls
 * back together.
 *
 * Partial-failure semantics (deliberate design choice): a bulk call over a
 * class routinely includes students who already have THIS exact structure
 * assigned for THIS academic year — `assignFeeStructure` throws
 * `DuplicateAssignmentError` for those. Treating that as fatal would make the
 * feature unusable (one already-assigned student would abort the whole
 * class). So a duplicate is SKIPPED AND REPORTED, not fatal, and the loop
 * continues to the next student. A genuine unexpected error (bad fee
 * structure, invoice failure, etc.) is NOT swallowed — it propagates and
 * aborts the whole transaction, because silently half-committing a bulk
 * assignment would be worse than failing loudly.
 *
 * Each per-student attempt is wrapped in its own SAVEPOINT so a Postgres
 * unique_violation (the app-level check above raced with a concurrent
 * writer) can be rolled back to WITHOUT poisoning the surrounding
 * transaction — mirrors `insertDemandIdempotent`'s
 * SAVEPOINT / ROLLBACK TO SAVEPOINT recovery in transport_write_handlers.ts.
 */
export async function bulkAssignFeeStructure(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: BulkAssignFeeStructureInput,
): Promise<BulkAssignResult> {
  const assigned: AssignmentWithAccount[] = [];
  const skipped: BulkAssignSkipped[] = [];

  for (const studentId of input.studentIds) {
    await db.queryObject(`SAVEPOINT bulk_fee_assignment`);
    try {
      const result = await assignFeeStructure(db, organizationId, schoolId, {
        studentId,
        feeStructureId: input.feeStructureId,
        academicYear: input.academicYear,
        assignedBy: input.assignedBy,
        admissionDate: input.admissionDate,
        prorationPolicyOverride: input.prorationPolicyOverride,
        prorationOverrideReason: input.prorationOverrideReason,
      });
      await db.queryObject(`RELEASE SAVEPOINT bulk_fee_assignment`);
      assigned.push(result);
    } catch (error) {
      if (error instanceof DuplicateAssignmentError || isUniqueViolation(error)) {
        await db.queryObject(`ROLLBACK TO SAVEPOINT bulk_fee_assignment`);
        skipped.push({ studentId, reason: "already_assigned" });
        continue;
      }
      // Any other error is unexpected — let it propagate so withTenantContext
      // rolls back the whole batch rather than half-committing it silently.
      throw error;
    }
  }

  return { assigned, skipped, total: input.studentIds.length };
}

export async function cancelAssignment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  assignmentId: string,
): Promise<AssignmentWithAccount | null> {
  const rows = await db.queryObject<FinanceFeeAssignmentRow>(
    `UPDATE finance_fee_assignments SET
      assignment_status = 'cancelled',
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
      AND assignment_status = 'active'
    RETURNING *`,
    [assignmentId, organizationId, schoolId],
  );
  const assignment = rows[0];
  if (!assignment) return null;

  const accountRows = await db.queryObject<FinanceStudentAccountRow>(
    `UPDATE finance_student_accounts SET
      status = 'closed',
      updated_at = timezone('utc', now())
    WHERE fee_assignment_id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [assignmentId, organizationId, schoolId],
  );

  return await enrichAssignmentWithAccount(
    db,
    organizationId,
    schoolId,
    assignment,
    accountRows[0]!,
  );
}

export async function getStudentAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  academicYear?: string,
): Promise<AssignmentWithAccount | null> {
  const accountSql = academicYear
    ? `SELECT * FROM finance_student_accounts
       WHERE student_id = $1 AND organization_id = $2 AND school_id = $3 AND academic_year = $4`
    : `SELECT * FROM finance_student_accounts
       WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
       ORDER BY created_at DESC LIMIT 1`;
  const accountArgs = academicYear
    ? [studentId, organizationId, schoolId, academicYear]
    : [studentId, organizationId, schoolId];

  const accountRows = await db.queryObject<FinanceStudentAccountRow>(
    accountSql,
    accountArgs,
  );
  const account = accountRows[0];
  if (!account) return null;

  const assignment = await getAssignment(
    db,
    organizationId,
    schoolId,
    account.fee_assignment_id,
  );
  if (!assignment) return null;

  const enrich = await enrichAssignmentWithAccount(
    db,
    organizationId,
    schoolId,
    assignment,
    account,
  );
  return enrich;
}

async function enrichAssignmentWithAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  assignment: FinanceFeeAssignmentRow,
  account: FinanceStudentAccountRow,
  invoice?: FinanceInvoiceRow,
): Promise<AssignmentWithAccount> {
  const structureRows = await db.queryObject<{ name: string }>(
    `SELECT name FROM finance_fee_structures WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [assignment.fee_structure_id, organizationId, schoolId],
  );
  const studentRows = await db.queryObject<{ display_name: string }>(
    `SELECT display_name FROM students WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [assignment.student_id, organizationId, schoolId],
  );
  const handoffRows = await db.queryObject<{
    admission_number: string;
    class_label: string;
    student_name: string;
  }>(
    `SELECT admission_number, class_label, student_name FROM admissions_fee_handoffs
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY created_at DESC LIMIT 1`,
    [assignment.student_id, organizationId, schoolId],
  );
  const handoff = handoffRows[0];

  const resolvedInvoice = invoice ?? await getInvoiceByAssignmentId(
    db,
    organizationId,
    schoolId,
    assignment.id,
  );
  if (!resolvedInvoice) {
    throw new Error(`Invoice not found for assignment: ${assignment.id}`);
  }

  return {
    assignment,
    account,
    invoice: resolvedInvoice,
    feeStructureName: structureRows[0]?.name,
    studentName: handoff?.student_name ?? studentRows[0]?.display_name,
    admissionNumber: handoff?.admission_number,
    classLabel: handoff?.class_label,
  };
}

export interface AssignFromHandoffOptions {
  // Cap 73 — same meaning as on AssignFeeStructureInput; threaded through so
  // the handoff-based single-assign path (the Dart client's ONLY per-student
  // assignment call) can also drive/override proration.
  admissionDate?: string;
  prorationPolicyOverride?: FeeProrationPolicy;
  prorationOverrideReason?: string;
}

/** Assign fee plan from admissions handoff (v6.1 §6 — status → completed). */
export async function assignFromHandoff(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  handoffId: string,
  feeStructureId: string | null,
  assignedBy: string,
  options: AssignFromHandoffOptions = {},
): Promise<AssignmentWithAccount> {
  const handoff = await getFeeHandoffById(db, organizationId, schoolId, handoffId);
  if (!handoff) {
    throw new Error(`Handoff not found: ${handoffId}`);
  }

  if (!ASSIGNABLE_HANDOFF_STATUSES.has(handoff.handoff_status)) {
    throw new HandoffNotReadyError(handoff.handoff_status);
  }

  const structureId = feeStructureId ?? handoff.recommended_fee_plan_id;
  if (!structureId) {
    throw new Error("fee_structure_id is required when handoff has no recommended fee plan");
  }

  const result = await createAssignmentAndAccount(db, organizationId, schoolId, {
    studentId: handoff.student_id,
    feeStructureId: structureId,
    academicYear: handoff.academic_year,
    assignedBy,
    admissionDate: options.admissionDate,
    prorationPolicyOverride: options.prorationPolicyOverride,
    prorationOverrideReason: options.prorationOverrideReason,
  });

  await db.queryObject(
    `UPDATE admissions_fee_handoffs SET
      handoff_status = 'completed',
      sis_handoff_label = 'Fee plan assigned',
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [handoffId, organizationId, schoolId],
  );

  return {
    ...result,
    studentName: handoff.student_name,
    admissionNumber: handoff.admission_number,
    classLabel: handoff.class_label,
  };
}
