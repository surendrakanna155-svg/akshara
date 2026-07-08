// FIN-6 — aging driven by the installment / term-wise due schedule.
//
// A student's days-overdue is computed from WHEN their fees were actually due.
// For each outstanding (issued / partially_paid) invoice the effective
// "overdue since" date is the due date of the EARLIEST installment term that is
// NOT YET COVERED by what has actually been paid on the invoice so far — terms
// are ordered by due date, their amounts cumulatively summed, and the first term
// whose running total exceeds the invoice's paid-to-date amount is the one still
// outstanding; if every term is already covered (or no schedule exists), it
// falls back to the invoice's own `due_date`. Aging = the greatest such gap that
// is already in the past. This is informational aging only — no money movement,
// the invoice's single outstanding stays authoritative.
//
// `finance_invoice_installments.status` is written once at issue and never
// updated (there is no reminder/collection path that flips pending→paid), so
// aging CANNOT trust `status` — it must derive "paid so far" from the invoice's
// own outstanding/total/late-fee columns instead (see `amountPaidExpr` below).
//
// Behaviour-preserving by default: the default `installment_terms = "1"` yields a
// single term whose due date equals the invoice `due_date` and whose amount
// equals the invoice total, so that term is always the "first uncovered" one
// (any partial payment still leaves it >0 outstanding) — single-term /
// un-scheduled invoices age exactly as before, byte-identical. Only genuine
// MULTI-term schedules change (they now correctly age off the earliest term
// that is still genuinely unpaid, instead of being pinned to term 1 forever).

/**
 * The invoice's cumulative amount actually paid so far. Collections only ever
 * move `outstanding_amount` (never `total_amount`); late-fee accrual/waive move
 * `outstanding_amount` and `late_fee_amount` in lockstep (see
 * `finance_late_fee_repository.ts`). So `total_amount - outstanding_amount` net
 * of any accrued-but-unpaid late fee is exactly what has been paid:
 *   amount_paid = total_amount - outstanding_amount + late_fee_amount
 */
const AMOUNT_PAID_EXPR =
  "(fi.total_amount - fi.outstanding_amount + fi.late_fee_amount)";

/**
 * SQL scalar sub-expression yielding a student's days-overdue (integer). Inline
 * it into a SELECT that exposes the student id + org id via the given column
 * expressions (e.g. `fsa.student_id`, `fsa.organization_id`). Every finance
 * aging read (defaulters, recovery call queue, intelligence) shares this ONE
 * expression so they can never diverge.
 */
export function overdueDaysSql(
  studentIdExpr: string,
  orgIdExpr: string,
): string {
  return `COALESCE((
      SELECT MAX(EXTRACT(day FROM now() - eff.effective_due))::int
        FROM (
          SELECT COALESCE(
                   (
                     SELECT sched.due_date
                       FROM (
                         SELECT ii.due_date,
                                SUM(ii.amount_minor) OVER (
                                  ORDER BY ii.due_date, ii.term_no
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                                ) AS running_total
                           FROM finance_invoice_installments ii
                          WHERE ii.invoice_id = fi.id
                       ) sched
                      WHERE sched.running_total > ${AMOUNT_PAID_EXPR}
                      ORDER BY sched.due_date
                      LIMIT 1
                   ),
                   fi.due_date) AS effective_due
            FROM finance_invoices fi
           WHERE fi.student_id = ${studentIdExpr}
             AND fi.organization_id = ${orgIdExpr}
             AND fi.invoice_status IN ('issued', 'partially_paid')
        ) eff
       WHERE eff.effective_due < CURRENT_DATE), 0)`;
}

/**
 * Pure mirror of the SQL predicate above (same algorithm: cumulative-sum the
 * installment amounts in due-date order, take the first term whose running
 * total exceeds `amountPaid`; fall back to `invoiceDueDate` when every term is
 * already covered or there is no schedule). Postgres has no in-process test
 * harness in this repo's `deno test` run, so this is what the unit tests below
 * exercise directly — any change to the SQL above MUST be mirrored here.
 */
export interface AgingInstallment {
  dueDate: string; // YYYY-MM-DD
  amount: number;
  termNo?: number;
}

export function pickEffectiveDueDate(
  installments: readonly AgingInstallment[],
  amountPaid: number,
  invoiceDueDate: string,
): string {
  const sorted = [...installments].sort((a, b) => {
    if (a.dueDate !== b.dueDate) return a.dueDate < b.dueDate ? -1 : 1;
    return (a.termNo ?? 0) - (b.termNo ?? 0);
  });
  let running = 0;
  for (const term of sorted) {
    running += term.amount;
    if (running > amountPaid) return term.dueDate;
  }
  return invoiceDueDate;
}
