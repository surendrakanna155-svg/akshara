-- W4 — Per-plan monthly SMS quota (owner decision #1).
--
-- Owner decision #1 (FINAL): SMS quotas are enforced per subscription plan, and
-- every limit is CONFIG-DRIVEN (never hardcoded). This adds the plan-level cap
-- into the EXISTING plan-limit system (subscription_plans + resolveSubscription),
-- alongside the student / school slabs and the storage cap — NOT a second limit
-- system.
--
-- DESIGN — deliberately mirrors the Batch-4 storage cap (20260889000000):
--   * the limit is a new nullable column on the EXISTING plan catalog. NULL =
--     unlimited (same convention as max_schools / max_storage_bytes), so NOTHING
--     changes on deploy — every existing plan stays NULL until an operator sets a
--     cap AND flips the master switch (ENTITLEMENT_ENFORCEMENT, default OFF).
--     Two independent brakes, exactly like the slab and storage limits.
--   * usage is NOT a new counter table. It is COUNTED from the authoritative,
--     append-only delivery ledger `notification_deliveries` — the only table that
--     records SMS sends (channel='sms', status='sent'). Counting existing records
--     avoids a mutable counter that could drift or lose an update under
--     concurrency, and needs no writer changes on the send path.
--
-- Enforcement lives in entitlements/entitlement_limits.enforceSmsQuota, a
-- fail-open, deploy-dark, config-driven gate structured exactly like
-- enforceStudentLimit.

-- ─── Plan SMS limit: a new column on the EXISTING plan catalog ────────────────
-- Monthly cap, integer count. NULL = unlimited. Left NULL on all existing plans
-- so nothing changes on deploy.
ALTER TABLE subscription_plans
  ADD COLUMN IF NOT EXISTS max_sms_per_month INTEGER
    CHECK (max_sms_per_month IS NULL OR max_sms_per_month >= 0);

COMMENT ON COLUMN subscription_plans.max_sms_per_month IS
  'W4 — per-plan monthly SMS cap (calendar month). NULL = unlimited. Config-driven; enforced by enforceSmsQuota against the notification_deliveries SMS-sent ledger.';

-- ─── Usage read path: index the monthly SMS-sent count query ──────────────────
-- enforceSmsQuota counts sent SMS for the current month:
--   ... WHERE organization_id = $1 AND channel = 'sms' AND status = 'sent'
--         AND coalesce(sent_at, created_at) >= date_trunc('month', now())
-- A partial index on the SMS-sent slice keeps that count cheap even for a large
-- deliveries table. No new table, no new writer.
CREATE INDEX IF NOT EXISTS idx_notification_deliveries_sms_sent
  ON notification_deliveries (organization_id, sent_at)
  WHERE channel = 'sms' AND status = 'sent';
