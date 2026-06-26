-- Wave 5 (NOT-1): per-event deep-link route on notification deliveries.
--
-- The FCM push payload (notification_providers.ts) and the Flutter push handler
-- (push_messaging_service.dart) already honor a `data.route` deep link, but the
-- enqueue paths had no way to carry one, so taps had no specific destination.
-- This adds the column; enqueue paths (incl. the publisher fan-out) populate it.
--
-- Forward-only, idempotent. `erp_tenant` already has DML on this table.

ALTER TABLE notification_deliveries
  ADD COLUMN IF NOT EXISTS route TEXT;

COMMENT ON COLUMN notification_deliveries.route IS
  'Optional in-app deep-link path (e.g. /parent/notices) forwarded to the push data.route so a tap lands on the relevant screen. NULL = category fallback (no specific deep link).';
