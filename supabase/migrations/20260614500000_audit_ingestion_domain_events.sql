-- v6.3 Sprint 5 — Audit ingestion + domain_events outbox

CREATE TABLE audit_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_event_id TEXT,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID REFERENCES schools (id),
  user_id UUID,
  user_role TEXT,
  correlation_id TEXT,
  event_type TEXT NOT NULL,
  category TEXT NOT NULL,
  entity_type TEXT,
  entity_id TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  source TEXT NOT NULL DEFAULT 'client',
  ip_address TEXT,
  user_agent TEXT,
  client_timestamp TIMESTAMPTZ,
  ingested_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT audit_events_source_check CHECK (source IN ('client', 'server'))
);

CREATE UNIQUE INDEX idx_audit_events_client_dedupe
  ON audit_events (organization_id, client_event_id)
  WHERE client_event_id IS NOT NULL;

CREATE INDEX idx_audit_events_org_created ON audit_events (organization_id, created_at DESC);
CREATE INDEX idx_audit_events_org_type ON audit_events (organization_id, event_type, created_at DESC);
CREATE INDEX idx_audit_events_correlation ON audit_events (correlation_id)
  WHERE correlation_id IS NOT NULL;

CREATE TABLE domain_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID REFERENCES schools (id),
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  correlation_id TEXT,
  source_module TEXT NOT NULL,
  idempotency_key TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  published_at TIMESTAMPTZ,
  CONSTRAINT domain_events_status_check CHECK (status IN ('pending', 'published', 'failed'))
);

CREATE UNIQUE INDEX idx_domain_events_idempotency
  ON domain_events (organization_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX idx_domain_events_pending
  ON domain_events (organization_id, status, created_at)
  WHERE status = 'pending';

ALTER TABLE audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_events FORCE ROW LEVEL SECURITY;
ALTER TABLE domain_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE domain_events FORCE ROW LEVEL SECURITY;

CREATE POLICY audit_events_tenant_read ON audit_events
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND (
      app_current_scope() = 'organization'
      OR (
        app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
    )
  );

CREATE POLICY audit_events_tenant_insert ON audit_events
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school', 'parent', 'student')
  );

CREATE POLICY domain_events_school_read ON domain_events
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND (
      app_current_scope() = 'organization'
      OR (
        app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
    )
  );

CREATE POLICY domain_events_school_insert ON domain_events
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school')
  );

CREATE POLICY domain_events_school_update ON domain_events
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school')
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school')
  );

GRANT SELECT, INSERT ON audit_events TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON domain_events TO erp_tenant;

-- Tenant isolation probes
INSERT INTO audit_events (
  id, organization_id, school_id, user_id, event_type, category, source, metadata
) VALUES
(
  'c0000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000001',
  'probe',
  'system',
  'server',
  '{"label":"Audit Probe A"}'::jsonb
),
(
  'c0000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'a3000000-0000-4000-8000-000000000001',
  'probe',
  'system',
  'server',
  '{"label":"Audit Probe B"}'::jsonb
);

INSERT INTO domain_events (
  id, organization_id, school_id, event_type, payload, source_module, idempotency_key, status, published_at
) VALUES
(
  'c1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'probe.domain_event',
  '{"label":"Domain Event Probe A"}'::jsonb,
  'platform',
  'probe.domain_event.a',
  'published',
  timezone('utc', now())
),
(
  'c1000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'probe.domain_event',
  '{"label":"Domain Event Probe B"}'::jsonb,
  'platform',
  'probe.domain_event.b',
  'published',
  timezone('utc', now())
);
