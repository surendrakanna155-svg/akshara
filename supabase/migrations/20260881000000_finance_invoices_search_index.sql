-- RT-11-7 (P4-RT-1 round 3) — the Universal Search "invoices" category
-- (search_repository.ts searchInvoices) filters `lower(fi.invoice_number) LIKE 'x%'`,
-- which the raw `UNIQUE(school_id, invoice_number)` index cannot serve. The
-- org/school index bounds the scan to one tenant, but every invoice within it is
-- then filtered/sorted without index support — degrading as invoices accumulate
-- each billing cycle over the school's lifetime.
--
-- This adds the functional prefix index the query shape needs, mirroring the
-- established search-index pattern (20260871/20260874). The student-name path in
-- the same query is already covered by idx_students_display_name_trgm (20260874).
-- Additive/dormant: index only, touches no data, changes no results.

CREATE INDEX IF NOT EXISTS idx_finance_invoices_school_number_lower
  ON finance_invoices (school_id, lower(invoice_number) text_pattern_ops);
