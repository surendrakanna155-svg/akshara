-- COM-2 (audience picker + saved segments) + COM-D1 (acknowledge-required
-- notices + signed-receipt log) — communication module.
--
-- (a) COM-2 AUDIENCE: extend a broadcast's addressability beyond the four
--     whole-cohort audiences to a SPECIFIC class (optionally a section):
--       * widen comm_broadcasts_audience_check to also allow 'class_parents'
--         (guardians of a class/section) and 'class_students' (the students of a
--         class/section).
--       * add nullable comm_broadcasts.audience_class / audience_section so the
--         chosen class/section is persisted on the broadcast and re-read at
--         (scheduled) dispatch time — audience membership is resolved when the
--         message actually goes out, not when it was authored.
--
-- (b) COM-2 SAVED SEGMENTS: comm_audience_segments lets a school save a named
--     audience (e.g. "Grade 5-A parents") and reuse it. School-scoped, FORCE RLS,
--     unique per (org, school, name). No UPDATE grant — segments are immutable;
--     you create or delete them.
--
-- (c) COM-D1 ACKNOWLEDGE: some notices require an explicit parent/recipient
--     acknowledgement (e.g. a policy the school must be able to PROVE was seen).
--       * comm_broadcasts.requires_ack marks a broadcast as acknowledge-required.
--       * notification_deliveries.requires_ack stamps each delivery so the
--         recipient's app can render the "I acknowledge" affordance, and
--         acknowledged_at records WHEN the recipient acknowledged. The
--         acknowledgement is additionally written as an immutable audit event
--         (notification.acknowledged) which is the authoritative signed-receipt
--         log; acknowledged_at on the delivery row is the queryable projection
--         used by the per-broadcast report.

-- ── (a) COM-2: class/section audiences on the broadcast ───────────────────────

ALTER TABLE comm_broadcasts DROP CONSTRAINT IF EXISTS comm_broadcasts_audience_check;
ALTER TABLE comm_broadcasts ADD CONSTRAINT comm_broadcasts_audience_check CHECK (
  audience IN (
    'all_parents', 'all_teachers', 'all_students', 'school_wide',
    'class_parents', 'class_students'
  )
);

ALTER TABLE comm_broadcasts ADD COLUMN audience_class TEXT;
ALTER TABLE comm_broadcasts ADD COLUMN audience_section TEXT;

-- ── (b) COM-2: saved audience segments ───────────────────────────────────────

CREATE TABLE comm_audience_segments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  name TEXT NOT NULL,
  audience_type TEXT NOT NULL,
  class_name TEXT,
  section_name TEXT,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, name)
);

CREATE INDEX idx_comm_audience_segments_school
  ON comm_audience_segments (organization_id, school_id);

ALTER TABLE comm_audience_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE comm_audience_segments FORCE ROW LEVEL SECURITY;

CREATE POLICY comm_audience_segments_school ON comm_audience_segments
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, DELETE ON comm_audience_segments TO erp_tenant;

-- ── (c) COM-D1: acknowledge-required notices + receipt timestamp ──────────────

ALTER TABLE notification_deliveries
  ADD COLUMN requires_ack BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE notification_deliveries
  ADD COLUMN acknowledged_at TIMESTAMPTZ;

ALTER TABLE comm_broadcasts
  ADD COLUMN requires_ack BOOLEAN NOT NULL DEFAULT false;
