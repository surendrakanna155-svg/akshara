import type { TenantQueryClient } from "../tenant_db.ts";

export type DiscountRuleStatus = "pending" | "approved" | "rejected" | "active";

const DISCOUNT_STATUSES: readonly DiscountRuleStatus[] = [
  "pending",
  "approved",
  "rejected",
  "active",
];

export interface FinanceDiscountRuleRow {
  id: string;
  organization_id: string;
  school_id: string;
  name: string;
  discount_percent: string;
  applies_to: string;
  status: DiscountRuleStatus;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateDiscountRuleInput {
  name: string;
  discountPercent: string;
  appliesTo: string;
  status?: DiscountRuleStatus;
  createdBy: string;
}

export interface UpdateDiscountRuleInput {
  name?: string;
  discountPercent?: string;
  appliesTo?: string;
  status?: DiscountRuleStatus;
}

export class DiscountRuleNotFoundError extends Error {
  constructor(id: string) {
    super(`Discount rule not found: ${id}`);
    this.name = "DiscountRuleNotFoundError";
  }
}

export function isDiscountRuleStatus(value: string): value is DiscountRuleStatus {
  return (DISCOUNT_STATUSES as readonly string[]).includes(value);
}

/** Map a DB row to the camelCase API shape expected by the Flutter mapper. */
export function discountRuleToApi(row: FinanceDiscountRuleRow): Record<string, unknown> {
  return {
    id: row.id,
    name: row.name,
    discountPercent: String(row.discount_percent),
    appliesTo: row.applies_to,
    status: row.status,
  };
}

export async function createDiscountRule(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateDiscountRuleInput,
): Promise<FinanceDiscountRuleRow> {
  const rows = await db.queryObject<FinanceDiscountRuleRow>(
    `INSERT INTO finance_discount_rules (
      organization_id, school_id, name, discount_percent, applies_to, status, created_by
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.name,
      input.discountPercent,
      input.appliesTo,
      input.status ?? "pending",
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export async function getDiscountRule(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  ruleId: string,
): Promise<FinanceDiscountRuleRow | null> {
  const rows = await db.queryObject<FinanceDiscountRuleRow>(
    `SELECT * FROM finance_discount_rules
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [ruleId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function updateDiscountRule(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  ruleId: string,
  input: UpdateDiscountRuleInput,
): Promise<FinanceDiscountRuleRow> {
  const existing = await getDiscountRule(db, organizationId, schoolId, ruleId);
  if (!existing) {
    throw new DiscountRuleNotFoundError(ruleId);
  }

  const rows = await db.queryObject<FinanceDiscountRuleRow>(
    `UPDATE finance_discount_rules
     SET name = COALESCE($4, name),
         discount_percent = COALESCE($5, discount_percent),
         applies_to = COALESCE($6, applies_to),
         status = COALESCE($7, status),
         updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
     RETURNING *`,
    [
      ruleId,
      organizationId,
      schoolId,
      input.name ?? null,
      input.discountPercent ?? null,
      input.appliesTo ?? null,
      input.status ?? null,
    ],
  );
  return rows[0]!;
}
