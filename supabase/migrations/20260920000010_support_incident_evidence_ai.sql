-- ASIP — Phase 1, migration 2/4: evidence snapshot + AI incident package.
--
-- The platform auto-collects a PII-MINIMIZED evidence snapshot at report time
-- (so the incident is reproducible + auditable and does not silently change as
-- the school mutates data afterward), and the AI Incident Package is assembled
-- deterministically from that evidence with an OPTIONAL governed-LLM enrichment.
--
-- Governance:
--   * Both tables are APPEND-ONLY (SELECT+INSERT grant only) — an immutable
--     forensic record. A re-collection / re-analysis writes a NEW row/version.
--   * support_incident_ai_analysis.approved_* stay NULL until a HUMAN accepts.
--     AI output is never auto-applied (Adaptive-AI doc 10 §12; ASIP_DESIGN §5).
--   * Org+school RLS, ENABLE+FORCE, erp_tenant grant — same house pattern.
-- Additive/dormant: no existing table or row is touched.

CREATE TABLE support_incident_evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  incident_id UUID NOT NULL REFERENCES support_incident (id) ON DELETE CASCADE,

  -- What slice of evidence this row holds. Each incident accumulates several
  -- rows (one per kind, possibly re-collected → newer collected_at wins).
  kind TEXT NOT NULL
    CHECK (kind IN (
      'client_context',   -- app version, device, os, session, route, module
      'breadcrumbs',      -- recent screen/API/error breadcrumbs (ring buffer)
      'audit_events',     -- the reporter's recent tenant audit events
      'api_calls',        -- recent correlated API failures / traces
      'workflow_state',   -- relevant approval/workflow state
      'diagnostics'       -- safe, computed diagnostics summary
    )),

  -- The evidence payload. PII-minimized by the collector (ids + aggregates +
  -- safe diagnostics, never raw student PII). JSONB so it stays queryable.
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- true when the collector redacted/omitted fields to honor PII-minimization;
  -- surfaced to support so "why is X missing" is answerable.
  redacted BOOLEAN NOT NULL DEFAULT false,

  collected_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_support_incident_evidence_incident
  ON support_incident_evidence (incident_id, kind, collected_at DESC);

ALTER TABLE support_incident_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_incident_evidence FORCE ROW LEVEL SECURITY;

CREATE POLICY support_incident_evidence_school_scope ON support_incident_evidence
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

-- Append-only forensic snapshot: no UPDATE/DELETE grant.
GRANT SELECT, INSERT ON support_incident_evidence TO erp_tenant;

-- ─── AI Incident Package (deterministic assembly + optional LLM enrichment) ────

CREATE TABLE support_incident_ai_analysis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  incident_id UUID NOT NULL REFERENCES support_incident (id) ON DELETE CASCADE,

  -- Monotonic per incident (1, 2, 3 …). A re-analysis appends a new version;
  -- history is preserved.
  version INT NOT NULL CHECK (version >= 1),

  -- Structured findings. All deterministic-first: even when the model declines
  -- (no key / rate / spend cap / timeout), these are filled from the evidence.
  categorization JSONB NOT NULL DEFAULT '{}'::jsonb,     -- {category, signals[]}
  severity_suggestion TEXT
    CHECK (severity_suggestion IS NULL
      OR severity_suggestion IN ('sev1', 'sev2', 'sev3', 'sev4')),
  summary TEXT NOT NULL DEFAULT '',
  likely_root_cause TEXT NOT NULL DEFAULT '',
  suggested_next_steps JSONB NOT NULL DEFAULT '[]'::jsonb,

  -- 0..100 heuristic/blended confidence. Explainable, never a mystery number.
  confidence INT NOT NULL DEFAULT 0 CHECK (confidence BETWEEN 0 AND 100),

  -- 'deterministic' when the whole package came from rules (model unavailable),
  -- 'ai_enriched' when a governed model call added narrative. Never fabricated.
  method TEXT NOT NULL DEFAULT 'deterministic'
    CHECK (method IN ('deterministic', 'ai_enriched')),
  model TEXT NOT NULL DEFAULT '',
  evidence_digest TEXT NOT NULL DEFAULT '',  -- hash of the evidence it read

  -- HUMAN approval. AI output is a DRAFT until a support engineer accepts it —
  -- never auto-applied to anything.
  approved_by UUID REFERENCES users (id),
  approved_at TIMESTAMPTZ,

  generated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT support_incident_ai_analysis_uq UNIQUE (incident_id, version)
);

CREATE INDEX idx_support_incident_ai_analysis_incident
  ON support_incident_ai_analysis (incident_id, version DESC);

ALTER TABLE support_incident_ai_analysis ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_incident_ai_analysis FORCE ROW LEVEL SECURITY;

CREATE POLICY support_incident_ai_analysis_school_scope ON support_incident_ai_analysis
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

-- Append-only + a single guarded UPDATE for the human-approval stamp. The
-- approval write is a narrow column set; the repository asserts approved_by is
-- the caller and only transitions NULL → set (no un-approve, no content edit).
GRANT SELECT, INSERT, UPDATE ON support_incident_ai_analysis TO erp_tenant;
