-- Wave 3 — security hardening (SEC-1, SEC-4). Forward-only.

-- ─── SEC-1: make the delivery-status webhook functional + tenant-safe ─────────
-- The handler matches deliveries by the provider's external reference and records
-- a confirmed delivery timestamp + 'delivered' status. Those columns/states did
-- not exist, so the webhook could never succeed. Add them.

ALTER TABLE notification_deliveries
  ADD COLUMN IF NOT EXISTS external_id TEXT,
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_notification_deliveries_external_id
  ON notification_deliveries (external_id)
  WHERE external_id IS NOT NULL;

-- Allow the provider-confirmed terminal state 'delivered'.
ALTER TABLE notification_deliveries
  DROP CONSTRAINT IF EXISTS notification_deliveries_status_check;
ALTER TABLE notification_deliveries
  ADD CONSTRAINT notification_deliveries_status_check
  CHECK (status IN ('pending', 'sent', 'failed', 'cancelled', 'delivered'));

-- ─── SEC-4: parent-scope RLS on AI parent-guidance reports ───────────────────
-- The table previously had only a school-scope policy. Add defense-in-depth so a
-- parent can read ONLY published guidance reports for their own linked children
-- (mirrors exam_mark_entries_school parent scoping).

DROP POLICY IF EXISTS intel_parent_guidance_parent_scope ON intel_parent_guidance_reports;
CREATE POLICY intel_parent_guidance_parent_scope ON intel_parent_guidance_reports
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND status = 'published'
    AND school_id = app_current_school_id()
    AND student_id IN (
      SELECT student_id FROM student_guardians
      WHERE guardian_user_id = app_current_parent_user_id()
        AND school_id = app_current_school_id()
    )
  );
