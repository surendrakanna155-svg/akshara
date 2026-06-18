-- F2 — unified cross-module approval requests (exam, leave, attendance, finance, PO)
-- Rules: FORCE RLS, school-scope operational access, erp_tenant grants

CREATE TABLE approval_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  requester_id TEXT NOT NULL,
  requester_name TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  decided_at TIMESTAMPTZ,
  decided_by_id TEXT,
  decided_by_name TEXT,
  decision_comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT approval_requests_status_check
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'))
);

CREATE INDEX idx_approval_requests_school_status
  ON approval_requests (school_id, status);
CREATE INDEX idx_approval_requests_school_type
  ON approval_requests (school_id, type);
CREATE INDEX idx_approval_requests_entity
  ON approval_requests (school_id, entity_type, entity_id);

CREATE UNIQUE INDEX idx_approval_requests_pending_entity
  ON approval_requests (school_id, type, entity_type, entity_id)
  WHERE status = 'pending';

CREATE TRIGGER approval_requests_updated_at
  BEFORE UPDATE ON approval_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE approval_audit_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  approval_request_id UUID NOT NULL REFERENCES approval_requests (id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  actor_id TEXT NOT NULL,
  actor_name TEXT NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  comment TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  CONSTRAINT approval_audit_action_check
    CHECK (action IN ('submitted', 'approved', 'rejected', 'cancelled'))
);

CREATE INDEX idx_approval_audit_request
  ON approval_audit_entries (approval_request_id, occurred_at);

CREATE TABLE approval_domain_effects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  approval_request_id UUID NOT NULL REFERENCES approval_requests (id) ON DELETE CASCADE,
  domain_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  effect_action TEXT NOT NULL,
  effect_payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT approval_domain_effect_action_check
    CHECK (effect_action IN ('approved', 'rejected'))
);

CREATE INDEX idx_approval_domain_effects_request
  ON approval_domain_effects (approval_request_id);

ALTER TABLE approval_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE approval_audit_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_audit_entries FORCE ROW LEVEL SECURITY;
ALTER TABLE approval_domain_effects ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_domain_effects FORCE ROW LEVEL SECURITY;

CREATE POLICY approval_requests_school_scope ON approval_requests
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

CREATE POLICY approval_audit_school_scope ON approval_audit_entries
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

CREATE POLICY approval_domain_effects_school_scope ON approval_domain_effects
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

GRANT SELECT, INSERT, UPDATE ON approval_requests TO erp_tenant;
GRANT SELECT, INSERT ON approval_audit_entries TO erp_tenant;
GRANT SELECT, INSERT ON approval_domain_effects TO erp_tenant;
