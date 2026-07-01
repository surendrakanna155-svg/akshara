// FIN-D4 — per-student fee-concession ledger (maker-checker).
//
// Recorded on the CHECKER's Approval-Center decision (approve → active, reject →
// rejected). The maker (approval requester) and checker (decider) are captured;
// maker != checker is already guaranteed by approval_repository.decideApproval's
// separation-of-duties guard. Applying the amount to the student's live payable is
// a documented follow-up (needs a resolved student_id + netting rules).

import type { TenantQueryClient } from "../tenant_db.ts";

export type FeeConcessionStatus = "active" | "rejected";

export interface FeeConcessionDecisionInput {
  sourceApprovalId: string;
  studentId: string | null;
  studentName: string;
  feeAccountRef: string;
  amountLabel: string;
  reason: string;
  makerId: string | null;
  checkerId: string | null;
  status: FeeConcessionStatus;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Keeps only a genuine UUID (approval requester/decider); else null (no FK break). */
export function asUuidOrNull(value: string | null | undefined): string | null {
  return value && UUID_RE.test(value) ? value : null;
}

/** Best-effort minor-unit (paise) parse of a free-text amount like "₹2,500" or "2500". */
export function parseAmountMinor(label: string): number | null {
  const digits = label.replace(/[^0-9.]/g, "");
  if (!digits) return null;
  const value = Number(digits);
  if (!Number.isFinite(value)) return null;
  return Math.round(value * 100);
}

export async function recordFeeConcessionDecision(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: FeeConcessionDecisionInput,
): Promise<{ id: string; status: string }> {
  const rows = await db.queryObject<{ id: string; status: string }>(
    `INSERT INTO finance_fee_concessions (
       organization_id, school_id, student_id, student_name, fee_account_ref,
       amount_label, amount_minor, reason, status, source_approval_id,
       maker_id, checker_id
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
     RETURNING id, status`,
    [
      organizationId,
      schoolId,
      asUuidOrNull(input.studentId),
      input.studentName,
      input.feeAccountRef,
      input.amountLabel,
      parseAmountMinor(input.amountLabel),
      input.reason,
      input.status,
      input.sourceApprovalId,
      asUuidOrNull(input.makerId),
      asUuidOrNull(input.checkerId),
    ],
  );
  return rows[0]!;
}

export interface FeeConcessionRow {
  id: string;
  student_name: string;
  amount_label: string;
  amount_minor: number | null;
  reason: string;
  status: string;
  maker_id: string | null;
  checker_id: string | null;
  decided_at: string;
}

export async function listFeeConcessions(
  db: TenantQueryClient,
): Promise<FeeConcessionRow[]> {
  return await db.queryObject<FeeConcessionRow>(
    `SELECT id, student_name, amount_label, amount_minor, reason, status,
            maker_id, checker_id, decided_at
       FROM finance_fee_concessions
      WHERE organization_id = app_current_tenant_id()
        AND school_id = app_current_school_id()
      ORDER BY created_at DESC`,
  );
}
