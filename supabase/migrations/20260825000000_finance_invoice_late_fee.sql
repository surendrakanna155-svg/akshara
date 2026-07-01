-- FIN-D5 — Late-fee accrual on overdue invoices.
--
-- An invoice past its due date (plus a configurable grace period) accrues a
-- flat-percent (optionally + flat) late fee, capped by the school's setting. The
-- accrued fee is ADDED to the invoice outstanding + the student-account
-- outstanding — it never alters the collection→invoice payment-reduction math.
--
-- Idempotency: `late_fee_amount = 0` means "not yet accrued"; the accrual pass
-- only touches invoices with late_fee_amount = 0, so re-running it is a no-op for
-- already-accrued invoices. `late_fee_accrued_at` records when the fee was
-- applied. Waiving reverses the amount from outstanding and resets both columns.
-- RBAC is the existing finance gate (manageFinance); no new permission.

ALTER TABLE finance_invoices
  ADD COLUMN late_fee_amount NUMERIC(12, 2) NOT NULL DEFAULT 0
    CHECK (late_fee_amount >= 0),
  ADD COLUMN late_fee_accrued_at TIMESTAMPTZ;
