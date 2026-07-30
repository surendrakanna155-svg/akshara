-- PRA-P1-41 (Owner decision #11, FINAL) — per-copy accession numbering + register.
--
-- Prior gap: the Library module modelled only TITLES (catalog rows in
-- library_entities carrying totalCopies / availableCopies counts). No physical
-- copy had an identity, so a school could not accession, track, or withdraw an
-- individual book — the way a real library register does.
--
-- This migration adds a per-copy accession model, mirroring the SIS Transfer-
-- Certificate engine's two-table shape (20260849000000) EXACTLY:
--
--   1. library_accession_counters — the per-(org, school) never-reused accession
--      number counter. Same RLS / grant / trigger shape as school_tc_counters:
--      a single row per (org, school) whose next_seq is advanced by an atomic
--      INSERT ... ON CONFLICT DO UPDATE. The DO UPDATE takes a row-level lock,
--      serializing concurrent allocations for the same library so every
--      accession number is DISTINCT, GAPLESS, and NEVER REUSED (no race-prone
--      MAX+1). First accession = 1.
--
--   2. library_accession_register — the accession register: one row per physical
--      copy (title ref, accession no, acquired date, cost, status). Status is
--      active | lost | withdrawn (integrates the existing lost-book concept with
--      a per-copy identity). A copy is WITHDRAWN, never physically deleted, so the
--      permanent accession record survives — hence SELECT/INSERT/UPDATE grant, NO
--      DELETE. School-scope FORCE RLS, exactly like library_entities.
--
-- Scope note: the library module is SCHOOL-scoped (library_entities RLS requires
-- app_current_scope() = 'school' AND school_id = app_current_school_id()), and the
-- ONLY working gapless-counter pattern in the codebase (school_tc_counters) is
-- keyed (organization_id, school_id) under that same school scope. Accession
-- numbers are therefore gapless per (org, school) = per school library — which is
-- the standard library-register scope (each library keeps its own accession run
-- starting at 1). An org-only counter would be incompatible with the library's
-- school-scoped RLS / tenant context.
--
-- Idempotent: CREATE ... IF NOT EXISTS, DROP/CREATE for triggers/policies.

-- ─── 1. Per-(org, school) never-reused accession number counter ──────────────
--
-- Mirrors school_tc_counters exactly (20260849000000). INSERT ... ON CONFLICT DO
-- UPDATE lands next_seq = 2 on the FIRST allocation (RETURNING next_seq - 1 = 1)
-- and, on conflict, bumps next_seq by one and RETURNS the pre-bump value. The DO
-- UPDATE row lock serializes concurrent allocations for the same (org, school).

CREATE TABLE IF NOT EXISTS library_accession_counters (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  next_seq INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id)
);

DROP TRIGGER IF EXISTS library_accession_counters_updated_at ON library_accession_counters;
CREATE TRIGGER library_accession_counters_updated_at
  BEFORE UPDATE ON library_accession_counters
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE library_accession_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE library_accession_counters FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS library_accession_counters_school_scope ON library_accession_counters;
CREATE POLICY library_accession_counters_school_scope ON library_accession_counters
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

GRANT SELECT, INSERT, UPDATE ON library_accession_counters TO erp_tenant;

-- ─── 2. Per-copy accession register ──────────────────────────────────────────
--
-- One row per physical copy. accession_no is the gapless number handed out by the
-- counter above; the UNIQUE (organization_id, school_id, accession_no) constraint
-- is the belt-and-suspenders integrity guard against a reused number (mirrors
-- uq_sis_certificate_issues_tc_serial). catalog_id is the library_entities catalog
-- (title) row id; isbn / title are a denormalized snapshot for display + lookup
-- (the same denormalization the issue/fine JSONB rows use — no FK into the shared
-- library_entities table, whose PK is composite).

CREATE TABLE IF NOT EXISTS library_accession_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  accession_no INTEGER NOT NULL CHECK (accession_no > 0),
  catalog_id TEXT NOT NULL,
  isbn TEXT,
  title TEXT,
  acquired_date DATE NOT NULL DEFAULT (timezone('utc', now())::date),
  cost NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'lost', 'withdrawn')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- The accession number is unique per library (never reused). This is the final
-- guard: even if the counter were bypassed, a duplicate accession number cannot
-- be inserted.
CREATE UNIQUE INDEX IF NOT EXISTS uq_library_accession_register_no
  ON library_accession_register (organization_id, school_id, accession_no);

-- Register-by-title (all copies of a book) and register-by-status (active /
-- lost / withdrawn rollups) are the two hot read paths.
CREATE INDEX IF NOT EXISTS idx_library_accession_register_catalog
  ON library_accession_register (organization_id, school_id, catalog_id);
CREATE INDEX IF NOT EXISTS idx_library_accession_register_status
  ON library_accession_register (organization_id, school_id, status);

DROP TRIGGER IF EXISTS library_accession_register_updated_at ON library_accession_register;
CREATE TRIGGER library_accession_register_updated_at
  BEFORE UPDATE ON library_accession_register
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE library_accession_register ENABLE ROW LEVEL SECURITY;
ALTER TABLE library_accession_register FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS library_accession_register_school_scope ON library_accession_register;
CREATE POLICY library_accession_register_school_scope ON library_accession_register
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

-- A copy is registered (INSERT), and its status transitions active -> lost /
-- withdrawn (UPDATE). It is NEVER physically deleted — a withdrawn copy keeps its
-- permanent accession record. Hence NO DELETE grant.
GRANT SELECT, INSERT, UPDATE ON library_accession_register TO erp_tenant;
