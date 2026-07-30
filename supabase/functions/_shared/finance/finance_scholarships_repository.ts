// Scholarships — full CRUD (this file) + a live admin screen
// (`finance_discounts_screen.dart`).
//
// A scholarship is a catalog entry (name, type, max_discount, eligibility). An
// active scholarship by itself changes no money — it is a template, not a
// per-student charge.
//
// PRA-P1-10 (S1): reducing a student's payable is now wired through the
// certified fee-reduction maker-checker (`finance_fee_reductions_repository.ts`),
// NOT a parallel mechanism. `awardScholarshipToInvoice` takes an active
// scholarship + a student's invoice and emits a PENDING fee-reduction
// (money-neutral) whose amount is derived from the scholarship's own
// `max_discount` (authoritative, never client-supplied). A second person (never
// the proposer) then approves it via /finance/fee-reductions/:id/approve — the
// only step that reduces the invoice + account payable, in lockstep,
// self-approval-blocked. Bulk assignment against `eligibility` remains a
// documented, owner-gated follow-up — this closes the per-student award path.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type FinanceFeeReductionRow,
  proposeFeeReduction,
} from "./finance_fee_reductions_repository.ts";

export type ScholarshipType =
  | "merit"
  | "need_based"
  | "sibling"
  | "staff_child"
  | "sports";

const SCHOLARSHIP_TYPES: readonly ScholarshipType[] = [
  "merit",
  "need_based",
  "sibling",
  "staff_child",
  "sports",
];

export interface FinanceScholarshipRow {
  id: string;
  organization_id: string;
  school_id: string;
  name: string;
  type: ScholarshipType;
  max_discount: string;
  eligibility: string;
  active_assignments: number;
  status: string;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateScholarshipInput {
  name: string;
  type: ScholarshipType;
  maxDiscount: string;
  eligibility: string;
  createdBy: string;
}

export interface UpdateScholarshipInput {
  name?: string;
  type?: ScholarshipType;
  maxDiscount?: string;
  eligibility?: string;
}

export class ScholarshipNotFoundError extends Error {
  constructor(id: string) {
    super(`Scholarship not found: ${id}`);
    this.name = "ScholarshipNotFoundError";
  }
}

export function isScholarshipType(value: string): value is ScholarshipType {
  return (SCHOLARSHIP_TYPES as readonly string[]).includes(value);
}

/** Map a DB row to the camelCase API shape expected by the Flutter mapper. */
export function scholarshipToApi(row: FinanceScholarshipRow): Record<string, unknown> {
  return {
    id: row.id,
    name: row.name,
    type: row.type,
    maxDiscount: row.max_discount,
    eligibility: row.eligibility,
    activeAssignments: row.active_assignments,
    status: row.status,
  };
}

export async function createScholarship(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateScholarshipInput,
): Promise<FinanceScholarshipRow> {
  const rows = await db.queryObject<FinanceScholarshipRow>(
    `INSERT INTO finance_scholarships (
      organization_id, school_id, name, type, max_discount, eligibility, created_by
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.name,
      input.type,
      input.maxDiscount,
      input.eligibility,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export async function getScholarship(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
): Promise<FinanceScholarshipRow | null> {
  const rows = await db.queryObject<FinanceScholarshipRow>(
    `SELECT * FROM finance_scholarships
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [id, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function listScholarships(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<FinanceScholarshipRow[]> {
  return await db.queryObject<FinanceScholarshipRow>(
    `SELECT * FROM finance_scholarships
     WHERE organization_id = $1 AND school_id = $2 AND status = 'active'
     ORDER BY created_at DESC`,
    [organizationId, schoolId],
  );
}

export async function updateScholarship(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  input: UpdateScholarshipInput,
): Promise<FinanceScholarshipRow> {
  const existing = await getScholarship(db, organizationId, schoolId, id);
  if (!existing) {
    throw new ScholarshipNotFoundError(id);
  }

  const rows = await db.queryObject<FinanceScholarshipRow>(
    `UPDATE finance_scholarships
     SET name = COALESCE($4, name),
         type = COALESCE($5, type),
         max_discount = COALESCE($6, max_discount),
         eligibility = COALESCE($7, eligibility),
         updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
     RETURNING *`,
    [
      id,
      organizationId,
      schoolId,
      input.name ?? null,
      input.type ?? null,
      input.maxDiscount ?? null,
      input.eligibility ?? null,
    ],
  );
  return rows[0]!;
}

// PRA-P1-10 (S1): raised when a scholarship cannot legitimately reduce a live
// payable — it is not active, or its free-text `max_discount` carries no
// machine-readable amount. Surfaced as a 422, never a 500.
export class ScholarshipNotApplicableError extends Error {
  constructor(id: string, detail: string) {
    super(`Scholarship ${id} cannot be applied to a payable (${detail})`);
    this.name = "ScholarshipNotApplicableError";
  }
}

export interface ScholarshipReductionSpec {
  reductionKind: "percent" | "fixed";
  percent?: number;
  fixedAmount?: number;
}

// PRA-P1-10 (S1): parse a scholarship's free-text `max_discount` into a machine
// reduction spec:
//   "50%" / "50 %"      → 50% percent reduction (rejected if > 100)
//   "5000" / "₹5,000"   → 5000 fixed reduction
//   ""    / "Full fee"  → null (no machine amount; the award must be rejected so
//                          nobody silently mis-reduces a payable)
// The scholarship value is authoritative — the client never supplies the amount.
export function parseMaxDiscount(raw: string | null | undefined): ScholarshipReductionSpec | null {
  const trimmed = (raw ?? "").trim();
  if (!trimmed) return null;
  const isPercent = trimmed.includes("%");
  const numeric = Number(trimmed.replace(/[^0-9.]/g, ""));
  if (!Number.isFinite(numeric) || numeric <= 0) return null;
  if (isPercent) {
    if (numeric > 100) return null;
    return { reductionKind: "percent", percent: numeric };
  }
  return { reductionKind: "fixed", fixedAmount: numeric };
}

export interface AwardScholarshipInput {
  /** Scholarship to award (its own max_discount is authoritative). */
  scholarshipId: string;
  /** Target student invoice — student + account are resolved FROM the invoice. */
  invoiceId: string;
  reason?: string;
  /** MAKER (server-set to claims.sub). Cannot later approve their own reduction. */
  createdBy: string;
}

// PRA-P1-10 (S1): award an active scholarship to a student's invoice by emitting
// a PENDING fee-reduction through the certified maker-checker path. Changes NO
// money on its own — it records the proposal with the amount taken from the
// scholarship (never the client). The reduction becomes real only when a
// DIFFERENT user approves it (self-approval blocked inside approveFeeReduction),
// which reduces the invoice + account in lockstep.
export async function awardScholarshipToInvoice(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: AwardScholarshipInput,
): Promise<FinanceFeeReductionRow> {
  const scholarship = await getScholarship(db, organizationId, schoolId, input.scholarshipId);
  if (!scholarship) {
    throw new ScholarshipNotFoundError(input.scholarshipId);
  }
  if (scholarship.status !== "active") {
    throw new ScholarshipNotApplicableError(input.scholarshipId, `status=${scholarship.status}`);
  }
  const spec = parseMaxDiscount(scholarship.max_discount);
  if (!spec) {
    throw new ScholarshipNotApplicableError(
      input.scholarshipId,
      `max_discount=${scholarship.max_discount}`,
    );
  }
  // Reuse the certified guarded MAKER step — do NOT duplicate its SQL/guards.
  return await proposeFeeReduction(db, organizationId, schoolId, {
    sourceKind: "scholarship",
    sourceId: scholarship.id,
    invoiceId: input.invoiceId,
    reductionKind: spec.reductionKind,
    percent: spec.percent,
    fixedAmount: spec.fixedAmount,
    reason: input.reason && input.reason.length > 0
      ? input.reason
      : `Scholarship: ${scholarship.name}`,
    createdBy: input.createdBy,
  });
}
