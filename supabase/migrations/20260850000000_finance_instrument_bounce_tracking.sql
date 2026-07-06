-- C12 · FIN-R7 — payment-instrument (cheque / DD / PDC) + bounce tracking.
--
-- Extends the EXISTING finance_offline_payments tracking ledger (added in
-- 20260801000000). This table is a record-keeping log ONLY — it never posts to
-- finance_collections and nothing sums it into dues/collected totals (verified:
-- referenced solely by finance_offline_payments_repository/handlers). Finance
-- stays the sole payment engine; a bounced instrument therefore posts NO money
-- and reverses NO money — it is a terminal tracking status. Reversal of any
-- money already collected against a bounced instrument stays a manual Finance
-- action through the existing reversal/refund path (money-safety tripwire).
--
-- Changes:
--   * payment_method CHECK += 'pdc' (post-dated cheque). instrument_date then
--     carries the cheque/PDC date (a PDC is a cheque dated in the future).
--   * status CHECK += 'bounced' — a terminal state alongside 'reconciled',
--     only reachable from 'pending_reconciliation'.
--   * instrument metadata: instrument_date DATE, bank_name TEXT.
--   * bounce audit trail: bounced_at, bounced_reason, bounced_by.
--
-- Forward-only, defensive (IF NOT EXISTS / DROP+ADD CHECK). No data backfill —
-- existing rows keep method cash/cheque/dd and status pending/reconciled.

ALTER TABLE finance_offline_payments
  ADD COLUMN IF NOT EXISTS instrument_date DATE,
  ADD COLUMN IF NOT EXISTS bank_name TEXT,
  ADD COLUMN IF NOT EXISTS bounced_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS bounced_reason TEXT,
  ADD COLUMN IF NOT EXISTS bounced_by UUID;

-- Widen the payment_method allow-list to include PDC.
ALTER TABLE finance_offline_payments
  DROP CONSTRAINT IF EXISTS finance_offline_payments_payment_method_check;
ALTER TABLE finance_offline_payments
  ADD CONSTRAINT finance_offline_payments_payment_method_check
  CHECK (payment_method IN ('cash', 'cheque', 'dd', 'pdc'));

-- Widen the status allow-list to include the terminal 'bounced' state.
ALTER TABLE finance_offline_payments
  DROP CONSTRAINT IF EXISTS finance_offline_payments_status_check;
ALTER TABLE finance_offline_payments
  ADD CONSTRAINT finance_offline_payments_status_check
  CHECK (status IN ('pending_reconciliation', 'reconciled', 'bounced'));
