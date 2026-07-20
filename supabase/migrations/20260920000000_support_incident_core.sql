-- ASIP (AI Support Intelligence Platform) — Phase 1, migration 1/4: incident core.
--
-- The platform-support system: customer school users report Akshara PRODUCT
-- issues (a bug/screen problem in the ERP itself) to the Akshara Support Team.
-- This is NOT the school's internal complaint system and NOT the control_center
-- mock. Design authority: docs/support-intelligence/ASIP_DESIGN.md.
--
-- Phase 1 is 100% WITHIN-TENANT: every row is org+school scoped under the proven
-- ENABLE+FORCE RLS house pattern, on the non-bypass erp_tenant role. Cross-tenant
-- Akshara-support visibility is Phase 2 and OWNER-GATED (Decision A) — nothing
-- here punches through the org wall.
--
-- Additive/dormant: no existing table or row is touched. Migration band
-- 20260920000000+ is claimed by ASIP, strictly above every current lane head
-- (main …876, DRP …897, PRA/trunk …900000019) so it splices cleanly at W0.
--
-- Reporter-privacy note: RLS scopes to the school (the platform norm — RLS knows
-- tenant/scope/school/user GUCs, not JWT permission slugs). "A reporter sees only
-- their OWN incidents; a viewSupport/manageSupport principal sees all school
-- incidents" is enforced at the edge handler layer (support_repository.ts), the
-- same finer-authz-on-top-of-school-RLS pattern used by the audit read path.

CREATE TABLE support_incident (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  -- Human-friendly reference shown to the reporter (e.g. SUP-1A2B3C4D). Derived
  -- from the row id so it is stable + unique + leaks no cross-tenant sequence.
  public_ref TEXT NOT NULL GENERATED ALWAYS AS
    ('SUP-' || upper(substr(replace(id::text, '-', ''), 1, 8))) STORED,

  -- WHO reported it (a school user). reporter_role is the primary role slug at
  -- report time, captured for triage (not an authz source).
  reporter_user_id UUID NOT NULL REFERENCES users (id),
  reporter_role TEXT NOT NULL DEFAULT '',

  -- The two things the school actually provides. Screenshot/recording live in
  -- support_incident_attachment (migration 3).
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',

  -- AI-suggestable but human-owned. category is a soft enum (free text within a
  -- known set) so new categories never require a migration.
  category TEXT NOT NULL DEFAULT 'unknown',

  -- Lifecycle. A row is born 'new'. Transitions are audited into
  -- support_incident_event and gated by manageSupport at the handler.
  status TEXT NOT NULL DEFAULT 'new'
    CHECK (status IN (
      'new', 'triaging', 'in_progress', 'awaiting_customer', 'resolved', 'closed'
    )),

  -- sev1 (critical/outage) … sev4 (cosmetic). Reporter never sets this; triage
  -- and the AI package suggest it, a human confirms.
  severity TEXT NOT NULL DEFAULT 'sev3'
    CHECK (severity IN ('sev1', 'sev2', 'sev3', 'sev4')),

  -- Auto-collected technical context (the school never types these). Nullable —
  -- best-effort capture; a missing field never blocks a report.
  module_key TEXT,
  screen_route TEXT,
  app_version TEXT,
  platform TEXT,          -- ios | android | web
  device_model TEXT,
  os_version TEXT,
  session_id TEXT,
  correlation_id TEXT,    -- the primary correlation id of the failing interaction

  -- Resolution bookkeeping.
  resolved_by UUID REFERENCES users (id),
  resolved_at TIMESTAMPTZ,
  resolution_summary TEXT,

  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT support_incident_title_len_ck CHECK (char_length(title) BETWEEN 1 AND 200),
  CONSTRAINT support_incident_desc_len_ck CHECK (char_length(description) <= 8000),
  CONSTRAINT support_incident_resolved_ck CHECK (
    status <> 'resolved' OR resolved_at IS NOT NULL
  )
);

CREATE INDEX idx_support_incident_org_school
  ON support_incident (organization_id, school_id, created_at DESC);
CREATE INDEX idx_support_incident_reporter
  ON support_incident (organization_id, school_id, reporter_user_id, created_at DESC);
CREATE INDEX idx_support_incident_status
  ON support_incident (school_id, status);
CREATE UNIQUE INDEX uq_support_incident_public_ref
  ON support_incident (public_ref);

CREATE TRIGGER support_incident_updated_at
  BEFORE UPDATE ON support_incident
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE support_incident ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_incident FORCE ROW LEVEL SECURITY;

CREATE POLICY support_incident_school_scope ON support_incident
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON support_incident TO erp_tenant;

-- ─── Timeline (append-only forensic trail of everything that happened) ─────────

CREATE TABLE support_incident_event (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  incident_id UUID NOT NULL REFERENCES support_incident (id) ON DELETE CASCADE,

  event_type TEXT NOT NULL
    CHECK (event_type IN (
      'created', 'status_changed', 'severity_changed', 'assigned', 'escalated',
      'evidence_collected', 'ai_analyzed', 'ai_analysis_approved',
      'message_posted', 'attachment_added', 'resolved', 'reopened'
    )),
  actor_user_id UUID REFERENCES users (id),   -- null for system/automatic events
  from_value TEXT,
  to_value TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_support_incident_event_incident
  ON support_incident_event (incident_id, created_at);

ALTER TABLE support_incident_event ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_incident_event FORCE ROW LEVEL SECURITY;

CREATE POLICY support_incident_event_school_scope ON support_incident_event
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- Append-only timeline: no UPDATE/DELETE grant.
GRANT SELECT, INSERT ON support_incident_event TO erp_tenant;

-- ─── Conversation (school-visible replies + Phase-2 internal notes) ────────────

CREATE TABLE support_incident_message (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  incident_id UUID NOT NULL REFERENCES support_incident (id) ON DELETE CASCADE,

  sender_user_id UUID REFERENCES users (id),  -- null only for 'system' messages
  sender_kind TEXT NOT NULL
    CHECK (sender_kind IN ('reporter', 'support', 'system')),

  -- internal_note rows are Phase-2 support-only working notes: never returned to
  -- a reporter-scoped read (enforced at the handler) and invisible to the school.
  visibility TEXT NOT NULL DEFAULT 'school_visible'
    CHECK (visibility IN ('school_visible', 'internal_note')),

  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT support_incident_message_body_len_ck CHECK (char_length(body) BETWEEN 1 AND 8000)
);

CREATE INDEX idx_support_incident_message_incident
  ON support_incident_message (incident_id, created_at);

ALTER TABLE support_incident_message ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_incident_message FORCE ROW LEVEL SECURITY;

CREATE POLICY support_incident_message_school_scope ON support_incident_message
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- Conversation is append-only (messages are never edited/deleted; a correction
-- is a new message). No UPDATE/DELETE grant.
GRANT SELECT, INSERT ON support_incident_message TO erp_tenant;
