-- 20260920000060 — ICA-A1 recovery money backfill (rupee-scale → integer paise).
--
-- ⚠️  ONE-TIME CORRECTION. NOT IDEMPOTENT BY DESIGN (it multiplies money ×100).
-- ⚠️  This migration MUST run EXACTLY ONCE. Re-running it multiplies the stored
--     amounts by another 100 and corrupts the recovery ledger. It carries no
--     guard on purpose — a guard that silently skipped a partially-applied state
--     would be worse than a hard, one-shot correction gated by the migration
--     ledger. The canonical-trunk deploy is owner-gated, so this executes only
--     at deploy time, exactly once.
--
-- WHY: the pre-fix fee-recovery writer (finance_recovery_handlers.amountMinor)
-- did `Math.round(x*100)/100` then `Math.trunc(x)`, so its ×100 and ÷100 cancelled
-- and it wrote RUPEE-magnitude values into the BIGINT paise columns
-- finance_promises_to_pay.amount_minor and finance_recovery_targets.target_minor.
-- The recovery dashboard's minorToRupees (÷100) then understated every promise /
-- target 100× (₹1,500 shown as ₹15.00). The writer is fixed on this trunk to
-- store true paise; this migration corrects the rows the OLD (unscaled) writer
-- persisted so historical rows read at the same (paise) scale as new ones.
--
-- SCOPE: finance_promises_to_pay.amount_minor and finance_recovery_targets.target_minor
-- ONLY. finance_fee_concessions.amount_minor is deliberately NOT touched — its
-- writer (finance_fee_concessions_repository.parseAmountMinor) already scaled
-- correctly to paise, so its rows are already right and must not be multiplied.

UPDATE finance_promises_to_pay SET amount_minor = amount_minor * 100;
UPDATE finance_recovery_targets SET target_minor = target_minor * 100;
