// FIN-6 — aging driven by the installment / term-wise due schedule.
//
// A student's days-overdue is computed from WHEN their fees were actually due.
// For each outstanding (issued / partially_paid) invoice the effective
// "overdue since" date is the EARLIEST installment term due date when a schedule
// exists, else the invoice's own `due_date`; aging = the greatest such gap that
// is already in the past. This is informational aging only — no money movement,
// the invoice's single outstanding stays authoritative.
//
// Behaviour-preserving by default: the default `installment_terms = "1"` yields a
// single term whose due date equals the invoice `due_date`, and legacy invoices
// with no schedule fall back to `due_date` — so single-term / un-scheduled
// invoices age exactly as before. Only genuine MULTI-term schedules change (they
// now correctly age from term 1's date).

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
                   (SELECT MIN(ii.due_date) FROM finance_invoice_installments ii
                     WHERE ii.invoice_id = fi.id),
                   fi.due_date) AS effective_due
            FROM finance_invoices fi
           WHERE fi.student_id = ${studentIdExpr}
             AND fi.organization_id = ${orgIdExpr}
             AND fi.invoice_status IN ('issued', 'partially_paid')
        ) eff
       WHERE eff.effective_due < CURRENT_DATE), 0)`;
}
