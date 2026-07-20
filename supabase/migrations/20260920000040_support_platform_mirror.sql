-- ASIP — Phase 2, migration 1: the platform-support MIRROR domain (Owner
-- Decision A1, 2026-07-20). Akshara support sees incidents across all schools
-- WITHOUT breaking the hard org wall: a school-side write calls a SECURITY
-- DEFINER bridge that copies a PII-minimized snapshot into mirror tables scoped
-- to a fixed platform-support organization (PLATFORM_ORG). Support staff are
-- normal principals of PLATFORM_ORG and read ONLY the mirror — never a school
-- tenant table. Resolution flows back through a second bridge.
--
-- Safety (Part 7B — tenant isolation + permission escalation):
--   * The mirror-write bridge reads the source org/school from the SESSION GUC
--     (app_current_tenant_id / app_current_school_id), NEVER from a parameter —
--     so a school can only ever mirror ITS OWN incidents; it cannot forge
--     another tenant's mirror rows.
--   * The mirror tables' RLS reads only when app_current_tenant_id() =
--     PLATFORM_ORG — a school session (its own org) can NEVER read the mirror.
--   * The resolution bridge asserts the caller IS PLATFORM_ORG — only support
--     can write a resolution back to a school incident.
--   * Every SECURITY DEFINER fn pins search_path and is REVOKEd from PUBLIC,
--     EXECUTE granted only to erp_tenant.
-- Additive/dormant. LIVE activation additionally needs PLATFORM_ORG + support
-- principals seeded — owner/deploy-gated (see ASIP_DESIGN §6.1).
--
-- DEFINER-OWNER REQUIREMENT (load-bearing): the three SECURITY DEFINER bridges
-- write RLS-FORCEd tables from a session whose GUC does NOT match the row scope
-- (school→mirror, support→school). They therefore rely on the function OWNER
-- bypassing RLS. This migration MUST be applied by a superuser / BYPASSRLS role
-- (the pilot applies migrations as `supabase_admin`, a superuser — the same role
-- that owns the existing `app.set_request_context` definer). The live cert
-- (`mirror:incident-written`) is the tripwire: if the owner cannot bypass RLS the
-- mirror stays empty and the cert fails. The tenant edge role `erp_tenant`
-- (NOBYPASSRLS) is never the owner, so support READS stay fully RLS-enforced.

-- Fixed platform-support organization id (constant, not a school tenant). Kept
-- as a helper so the id lives in exactly one place.
CREATE OR REPLACE FUNCTION app_support_platform_org()
  RETURNS uuid LANGUAGE sql IMMUTABLE AS
$$ SELECT 'a5100000-0000-4000-8000-000000000001'::uuid $$;

-- ─── Mirror incident (id = source incident id; 1:1 with support_incident) ──────

CREATE TABLE support_platform_incident (
  -- Same id as the school-side support_incident (globally-unique uuid) so the
  -- console and the school reference one identity.
  id UUID PRIMARY KEY,
  platform_org_id UUID NOT NULL,
  source_org_id UUID NOT NULL,
  source_school_id UUID NOT NULL,

  public_ref TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT 'unknown',
  severity TEXT NOT NULL DEFAULT 'sev3',
  -- The school-side lifecycle status (mirrored).
  source_status TEXT NOT NULL DEFAULT 'new',
  module_key TEXT,
  screen_route TEXT,
  app_version TEXT,
  platform TEXT,

  -- Support-side workflow (owned by the console; the mirror-write never touches
  -- these so a school update can't clobber triage state).
  support_status TEXT NOT NULL DEFAULT 'queue'
    CHECK (support_status IN ('queue', 'investigating', 'awaiting_engineering', 'resolved')),
  assigned_to UUID,
  escalated_at TIMESTAMPTZ,
  cluster_id UUID,

  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  mirrored_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_support_platform_incident_queue
  ON support_platform_incident (platform_org_id, support_status, mirrored_at DESC);
CREATE INDEX idx_support_platform_incident_cluster
  ON support_platform_incident (cluster_id);
CREATE INDEX idx_support_platform_incident_source
  ON support_platform_incident (source_org_id, source_school_id);

ALTER TABLE support_platform_incident ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_platform_incident FORCE ROW LEVEL SECURITY;

-- Readable/updatable ONLY by a PLATFORM_ORG session (support staff). A school
-- session (tenant = its own org) never matches, so the mirror is invisible to
-- schools. Writes to the mirror happen through the SECURITY DEFINER bridge, not
-- this policy; support-side triage updates (assign/status/cluster) go through it.
CREATE POLICY support_platform_incident_platform_scope ON support_platform_incident
  FOR ALL
  USING (
    app_current_tenant_id() = app_support_platform_org()
    AND platform_org_id = app_support_platform_org()
  )
  WITH CHECK (
    app_current_tenant_id() = app_support_platform_org()
    AND platform_org_id = app_support_platform_org()
  );

GRANT SELECT, UPDATE ON support_platform_incident TO erp_tenant;

-- ─── Mirror evidence (PII-minimized snapshot copy) ─────────────────────────────

CREATE TABLE support_platform_evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_org_id UUID NOT NULL,
  incident_id UUID NOT NULL REFERENCES support_platform_incident (id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  collected_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT support_platform_evidence_uq UNIQUE (incident_id, kind)
);

CREATE INDEX idx_support_platform_evidence_incident
  ON support_platform_evidence (incident_id);

ALTER TABLE support_platform_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_platform_evidence FORCE ROW LEVEL SECURITY;

CREATE POLICY support_platform_evidence_platform_scope ON support_platform_evidence
  FOR ALL
  USING (
    app_current_tenant_id() = app_support_platform_org()
    AND platform_org_id = app_support_platform_org()
  )
  WITH CHECK (
    app_current_tenant_id() = app_support_platform_org()
    AND platform_org_id = app_support_platform_org()
  );

GRANT SELECT ON support_platform_evidence TO erp_tenant;

-- ─── Support internal notes (on the mirror; never seen by the school) ──────────

CREATE TABLE support_platform_note (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_org_id UUID NOT NULL,
  incident_id UUID NOT NULL REFERENCES support_platform_incident (id) ON DELETE CASCADE,
  author_user_id UUID NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT support_platform_note_body_len_ck CHECK (char_length(body) BETWEEN 1 AND 8000)
);

CREATE INDEX idx_support_platform_note_incident
  ON support_platform_note (incident_id, created_at);

ALTER TABLE support_platform_note ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_platform_note FORCE ROW LEVEL SECURITY;

CREATE POLICY support_platform_note_platform_scope ON support_platform_note
  FOR ALL
  USING (
    app_current_tenant_id() = app_support_platform_org()
    AND platform_org_id = app_support_platform_org()
  )
  WITH CHECK (
    app_current_tenant_id() = app_support_platform_org()
    AND platform_org_id = app_support_platform_org()
  );

GRANT SELECT, INSERT ON support_platform_note TO erp_tenant;

-- ─── Incident cluster ("investigate once, resolve many") ───────────────────────

CREATE TABLE support_cluster (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_org_id UUID NOT NULL,
  cluster_key TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT 'unknown',
  module_key TEXT,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'investigating', 'resolved')),
  root_cause TEXT NOT NULL DEFAULT '',
  resolution TEXT NOT NULL DEFAULT '',
  incident_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT support_cluster_key_uq UNIQUE (platform_org_id, cluster_key)
);

CREATE INDEX idx_support_cluster_status
  ON support_cluster (platform_org_id, status, updated_at DESC);

ALTER TABLE support_cluster ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_cluster FORCE ROW LEVEL SECURITY;

CREATE POLICY support_cluster_platform_scope ON support_cluster
  FOR ALL
  USING (
    app_current_tenant_id() = app_support_platform_org()
    AND platform_org_id = app_support_platform_org()
  )
  WITH CHECK (
    app_current_tenant_id() = app_support_platform_org()
    AND platform_org_id = app_support_platform_org()
  );

GRANT SELECT, INSERT, UPDATE ON support_cluster TO erp_tenant;

-- ─── SECURITY DEFINER bridges (the ONLY cross-boundary write paths) ────────────

-- Mirror-write: called from the SCHOOL side after an incident create/update. The
-- source org/school come from the session GUC (never a parameter), so a school
-- can only mirror ITS OWN incident. Support-side triage columns are never
-- overwritten. Runs as the definer (owner) so it bypasses the mirror RLS for the
-- write only.
CREATE OR REPLACE FUNCTION app_support_mirror_incident(
  p_incident uuid,
  p_public_ref text,
  p_title text,
  p_description text,
  p_category text,
  p_severity text,
  p_status text,
  p_module_key text,
  p_screen_route text,
  p_app_version text,
  p_platform text,
  p_first_seen_at timestamptz
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS
$$
DECLARE
  v_org uuid := app_current_tenant_id();
  v_school uuid := app_current_school_id();
BEGIN
  IF v_org IS NULL OR v_school IS NULL THEN
    RAISE EXCEPTION 'support mirror requires a school-scoped session';
  END IF;
  -- A school may never target the platform org as a "source".
  IF v_org = app_support_platform_org() THEN
    RAISE EXCEPTION 'platform org cannot mirror as a source';
  END IF;

  INSERT INTO support_platform_incident (
    id, platform_org_id, source_org_id, source_school_id, public_ref, title,
    description, category, severity, source_status, module_key, screen_route,
    app_version, platform, first_seen_at
  ) VALUES (
    p_incident, app_support_platform_org(), v_org, v_school, p_public_ref, p_title,
    p_description, p_category, p_severity, p_status, p_module_key, p_screen_route,
    p_app_version, p_platform, COALESCE(p_first_seen_at, timezone('utc', now()))
  )
  ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    severity = EXCLUDED.severity,
    source_status = EXCLUDED.source_status,
    module_key = EXCLUDED.module_key,
    updated_at = timezone('utc', now())
  WHERE support_platform_incident.source_org_id = v_org;  -- never touch another tenant's row
END;
$$;

-- Mirror-write for one PII-minimized evidence part. Asserts the mirror incident
-- belongs to the caller's org (defense in depth).
CREATE OR REPLACE FUNCTION app_support_mirror_evidence(
  p_incident uuid,
  p_kind text,
  p_payload jsonb
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS
$$
DECLARE
  v_org uuid := app_current_tenant_id();
BEGIN
  IF v_org IS NULL OR v_org = app_support_platform_org() THEN
    RAISE EXCEPTION 'evidence mirror requires a school-scoped session';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM support_platform_incident
    WHERE id = p_incident AND source_org_id = v_org
  ) THEN
    RAISE EXCEPTION 'cannot mirror evidence for an incident you do not own';
  END IF;

  INSERT INTO support_platform_evidence (platform_org_id, incident_id, kind, payload)
  VALUES (app_support_platform_org(), p_incident, p_kind, p_payload)
  ON CONFLICT (incident_id, kind) DO UPDATE SET
    payload = EXCLUDED.payload,
    collected_at = timezone('utc', now());
END;
$$;

-- Resolution-write-back: called from the SUPPORT side (PLATFORM_ORG session). It
-- asserts the caller IS the platform org (so a school can't forge a resolution),
-- looks up the mirror to find the source school incident, and writes the
-- resolution back to it. Bypasses the school RLS as the definer, but only for the
-- exact source incident recorded in the mirror.
CREATE OR REPLACE FUNCTION app_support_propagate_resolution(
  p_incident uuid,
  p_source_status text,
  p_resolution text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS
$$
DECLARE
  v_caller uuid := app_current_tenant_id();
  v_src_org uuid;
BEGIN
  IF v_caller IS DISTINCT FROM app_support_platform_org() THEN
    RAISE EXCEPTION 'only the platform-support org may propagate a resolution';
  END IF;

  SELECT source_org_id INTO v_src_org
  FROM support_platform_incident
  WHERE id = p_incident AND platform_org_id = app_support_platform_org();
  IF v_src_org IS NULL THEN
    RAISE EXCEPTION 'mirror incident not found';
  END IF;

  UPDATE support_incident
     SET status = p_source_status,
         resolution_summary = p_resolution,
         resolved_by = CASE WHEN p_source_status = 'resolved' THEN resolved_by ELSE resolved_by END,
         resolved_at = CASE WHEN p_source_status = 'resolved' AND resolved_at IS NULL
                            THEN timezone('utc', now()) ELSE resolved_at END,
         updated_at = timezone('utc', now())
   WHERE id = p_incident AND organization_id = v_src_org;

  UPDATE support_platform_incident
     SET source_status = p_source_status, updated_at = timezone('utc', now())
   WHERE id = p_incident;
END;
$$;

-- Lock the bridges down: no PUBLIC execute; only the tenant edge role.
REVOKE ALL ON FUNCTION app_support_mirror_incident(uuid, text, text, text, text, text, text, text, text, text, text, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION app_support_mirror_evidence(uuid, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION app_support_propagate_resolution(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app_support_mirror_incident(uuid, text, text, text, text, text, text, text, text, text, text, timestamptz) TO erp_tenant;
GRANT EXECUTE ON FUNCTION app_support_mirror_evidence(uuid, text, jsonb) TO erp_tenant;
GRANT EXECUTE ON FUNCTION app_support_propagate_resolution(uuid, text, text) TO erp_tenant;

-- Support-side permission slug (granted to the platformSupport role, seeded when
-- PLATFORM_ORG + support principals are provisioned — owner/deploy-gated).
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('platformSupport', 'PlatformSupport', 'manage', 'organization',
   'Akshara support: triage/investigate incidents across schools (platform org only)')
ON CONFLICT (slug) DO NOTHING;
