// Scholarships — full CRUD (this file) + a live admin screen
// (`finance_discounts_screen.dart`), but NOT-YET-APPLIED to live payable: no
// fee-structure/invoice/assignment code path reads `finance_scholarships` to
// reduce a student's fee. A scholarship marked "active" (and any student
// assignment against it) only records intent — it does NOT change any
// invoice/outstanding amount. Same not-yet-applied caveat as FIN-D4 fee
// concessions (`finance_fee_concessions_repository.ts`); wiring the actual
// reduction into invoice/assignment totals is a documented, owner-gated
// follow-up.

import type { TenantQueryClient } from "../tenant_db.ts";

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
