// Discount rules — full CRUD (this file) + a live admin screen
// (`finance_discounts_screen.dart`).
//
// A discount RULE is a template (name, percent, scope, status). Marking a rule
// "approved"/"active" is a GOVERNANCE state — by itself it still changes no
// money (a template is not a per-student charge).
//
// PRA-P1-10 (S1): the missing link — actually reducing a student's payable — is
// now wired through the certified fee-reduction maker-checker
// (`finance_fee_reductions_repository.ts`), NOT a parallel mechanism.
// `applyDiscountRuleToInvoice` takes an approved/active rule + a student's
// invoice and emits a PENDING fee-reduction (money-neutral) whose percent is
// derived from the RULE (authoritative, never client-supplied). A second person
// (never the proposer) then approves it via /finance/fee-reductions/:id/approve,
// which is the only step that reduces the invoice + account payable, in
// lockstep, self-approval-blocked. Applying a rule to EVERY matching student in
// bulk (eligibility matching against `applies_to`) remains a documented,
// owner-gated follow-up — this closes the per-student reduction path only.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type FinanceFeeReductionRow,
  proposeFeeReduction,
} from "./finance_fee_reductions_repository.ts";

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

export async function listDiscountRules(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<FinanceDiscountRuleRow[]> {
  return await db.queryObject<FinanceDiscountRuleRow>(
    `SELECT * FROM finance_discount_rules
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY created_at DESC`,
    [organizationId, schoolId],
  );
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

// PRA-P1-10 (S1): raised when a rule cannot legitimately reduce a live payable —
// it is not governance-approved (still pending/rejected) or has no usable
// percent. Surfaced as a 422, never a 500.
export class DiscountRuleNotApplicableError extends Error {
  constructor(id: string, detail: string) {
    super(`Discount rule ${id} cannot be applied to a payable (${detail})`);
    this.name = "DiscountRuleNotApplicableError";
  }
}

export interface ApplyDiscountRuleInput {
  /** Discount rule to apply (its own discount_percent is authoritative). */
  ruleId: string;
  /** Target student invoice — student + account are resolved FROM the invoice. */
  invoiceId: string;
  reason?: string;
  /** MAKER (server-set to claims.sub). Cannot later approve their own reduction. */
  createdBy: string;
}

// PRA-P1-10 (S1): apply an approved/active discount rule to a student's invoice
// by emitting a PENDING fee-reduction through the certified maker-checker path.
// This changes NO money on its own — it only records the proposal, with the
// percent taken from the RULE (never the client). The reduction becomes real
// only when a DIFFERENT user approves it (self-approval blocked inside
// approveFeeReduction), which reduces the invoice + account in lockstep.
export async function applyDiscountRuleToInvoice(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: ApplyDiscountRuleInput,
): Promise<FinanceFeeReductionRow> {
  const rule = await getDiscountRule(db, organizationId, schoolId, input.ruleId);
  if (!rule) {
    throw new DiscountRuleNotFoundError(input.ruleId);
  }
  // Only a governance-approved (or active) rule may reduce a live payable — a
  // pending/rejected rule must never touch a student's fee.
  if (rule.status !== "approved" && rule.status !== "active") {
    throw new DiscountRuleNotApplicableError(input.ruleId, `status=${rule.status}`);
  }
  const percent = Number(rule.discount_percent);
  if (!(percent > 0 && percent <= 100)) {
    throw new DiscountRuleNotApplicableError(
      input.ruleId,
      `discount_percent=${rule.discount_percent}`,
    );
  }
  // Reuse the certified guarded MAKER step — do NOT duplicate its SQL/guards.
  return await proposeFeeReduction(db, organizationId, schoolId, {
    sourceKind: "discount",
    sourceId: rule.id,
    invoiceId: input.invoiceId,
    reductionKind: "percent",
    percent,
    reason: input.reason && input.reason.length > 0
      ? input.reason
      : `Discount rule: ${rule.name}`,
    createdBy: input.createdBy,
  });
}
