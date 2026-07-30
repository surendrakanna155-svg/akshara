-- 20260920000062 — ICA-A6: payment amount columns store rupees, not truncated ₹.
--
-- payment_requests.amount and payment_intents.amount were INTEGER, silently
-- truncating any rupee amount carrying paise (e.g. ₹1500.50 → 1500) the moment a
-- request/intent was persisted — before the value ever reached the collection /
-- receipt path. The finance money standard for a non-`_minor` money column is
-- NUMERIC(12,2) rupees; align these two columns to it (the same scale as
-- finance_collections.amount_collected, so the capture path stays exact).
--
-- NO code change is required (verified):
--   * razorpay_client.ts converts rupees → paise (amount * 100) at the gateway
--     boundary — still correct with a decimal rupee amount.
--   * payment_service.ts passes intent.amount straight into
--     finance_collections.amount_collected (already NUMERIC(12,2)).
--   * payment_handlers.ts parses the request body amount as a decimal Number().
--
-- Idempotent: ALTERing a column that is already NUMERIC(12,2) is a no-op, and the
-- USING cast is decimal-safe from either INTEGER or NUMERIC.

ALTER TABLE payment_requests
  ALTER COLUMN amount TYPE NUMERIC(12, 2) USING amount::numeric(12, 2);

ALTER TABLE payment_intents
  ALTER COLUMN amount TYPE NUMERIC(12, 2) USING amount::numeric(12, 2);
