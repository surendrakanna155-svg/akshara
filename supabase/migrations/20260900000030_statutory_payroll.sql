-- PRA-P1-35 (Owner decision #9, FINAL) — statutory payroll compliance (PF/ESI/PT/TDS).
--
-- Ships the persistence for a config-driven statutory-deduction engine (hr-owned).
-- The ENGINE lives in _shared/hr/statutory_payroll.ts and is entirely config-driven:
-- every rate, ceiling, threshold and slab is a row in these tables, NOT a constant
-- in code. A component with a rate of 0 (the column DEFAULT) deducts nothing, so an
-- unconfigured tenant is deploy-safe — no compliance number is ever guessed.
--
--   1. statutory_component_config — one rule PER (component, jurisdiction) per
--      school: employee/employer rates, the wage the rate applies to, the base cap
--      (PF ceiling), the eligibility ceiling/floor (ESI gate) and optional flat
--      amounts. Components: 'pf','esi','pt','tds'. State "" = central (PF/ESI/TDS);
--      a state code scopes a state-specific component (PT).
--
--   2. statutory_pt_slabs — per-STATE Professional-Tax slabs (a flat amount for a
--      monthly-gross band). PT varies by state, so its slabs are DATA rows, one per
--      band. A `month` override models states with a special month (e.g. a higher
--      February slab) without any code change.
--
--   3. payroll_statutory_liabilities — the per-run, per-component statutory
--      LIABILITY posted when a payroll run is PROCESSED: Σ employee withholding +
--      Σ employer contribution = the remittance owed to each authority (PF/ESI =
--      both shares; PT/TDS = employee only). This is the statutory-liability half of
--      the P0-24 payroll→Finance posting; the net-disbursement posting
--      (payroll_finance_postings, …019) is unchanged.
--
-- Idempotency (no double-post): UNIQUE
--   (organization_id, school_id, payroll_run_id, component, state)
-- backs the repo's INSERT ... ON CONFLICT DO NOTHING — re-processing a run (already
-- refused upstream by the 409 re-process guard) can never double-post a liability.
--
-- RLS / grants / trigger mirror the per-school hr-owned payroll_finance_postings
-- (…019) and leave_accrual (…024) precedents. Migration number 20260900000030 is
-- the next free slot above the …015–026 band (…027–029 unused) and clear of the
-- Data-Reliability / PRC 20260877–20260890 band, so a later merge cannot collide.

-- ── 1. Config-driven per-component statutory rule ─────────────────────────────
CREATE TABLE IF NOT EXISTS statutory_component_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- The statutory component this rule configures. The engine's PER-COMPONENT
  -- FORMULA (cap vs eligibility-gate vs slab) is keyed off this; the NUMBERS are
  -- the columns below. Never a hardcoded rate anywhere in code.
  component TEXT NOT NULL CHECK (component IN ('pf', 'esi', 'pt', 'tds')),
  -- Jurisdiction key. '' = central/all (PF, ESI, TDS are central Acts); a state
  -- code (e.g. 'KA', 'MH', 'AP') scopes a state-specific component (PT).
  state TEXT NOT NULL DEFAULT '',
  -- Employee/employer contribution RATES as fractions (0.12 = 12%). DEFAULT 0 so
  -- an unconfigured component deducts NOTHING (deploy-safe).
  employee_rate NUMERIC(8, 5) NOT NULL DEFAULT 0 CHECK (employee_rate >= 0),
  employer_rate NUMERIC(8, 5) NOT NULL DEFAULT 0 CHECK (employer_rate >= 0),
  -- Which wage the rate applies to: 'gross' (basic + allowances) or 'basic'.
  wage_base TEXT NOT NULL DEFAULT 'gross' CHECK (wage_base IN ('gross', 'basic')),
  -- Caps the wage the rate is applied to (the PF statutory wage ceiling). Earnings
  -- above it accrue no extra contribution. NULL = no cap.
  base_cap NUMERIC(14, 2) CHECK (base_cap IS NULL OR base_cap >= 0),
  -- Eligibility ceiling: when the wage EXCEEDS this the component does NOT apply at
  -- all (the ESI wage ceiling — a gate, not a base cap). NULL = always eligible.
  eligibility_ceiling NUMERIC(14, 2) CHECK (eligibility_ceiling IS NULL OR eligibility_ceiling >= 0),
  -- Eligibility floor: when the wage is BELOW this the component does not apply.
  -- NULL = no floor.
  eligibility_floor NUMERIC(14, 2) CHECK (eligibility_floor IS NULL OR eligibility_floor >= 0),
  -- Flat monthly amounts that OVERRIDE the rate (e.g. a flat monthly TDS, or a flat
  -- PT for a tenant not using slabs). NULL = use the rate.
  flat_employee NUMERIC(14, 2) CHECK (flat_employee IS NULL OR flat_employee >= 0),
  flat_employer NUMERIC(14, 2) CHECK (flat_employer IS NULL OR flat_employer >= 0),
  -- Statutory rounding of each computed share: 'nearest' rupee, 'up' (ESI rounds up
  -- to the next rupee), or 'none' (keep paise).
  rounding TEXT NOT NULL DEFAULT 'nearest' CHECK (rounding IN ('none', 'nearest', 'up')),
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- One rule per component per jurisdiction per school.
  UNIQUE (organization_id, school_id, component, state)
);

CREATE INDEX IF NOT EXISTS idx_statutory_component_config_school
  ON statutory_component_config (school_id, active);

CREATE TRIGGER statutory_component_config_updated_at
  BEFORE UPDATE ON statutory_component_config
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE statutory_component_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE statutory_component_config FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS statutory_component_config_school_scope ON statutory_component_config;
CREATE POLICY statutory_component_config_school_scope ON statutory_component_config
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

-- Config is set (SELECT/INSERT/UPDATE) but never deleted from code (deactivate via active=false).
GRANT SELECT, INSERT, UPDATE ON statutory_component_config TO erp_tenant;

-- ── 2. Per-state Professional-Tax slabs (flat amount for a monthly-gross band) ──
CREATE TABLE IF NOT EXISTS statutory_pt_slabs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- The state whose PT schedule this slab belongs to.
  state TEXT NOT NULL,
  -- Monthly gross band [lower_bound, upper_bound]. upper_bound NULL = top slab.
  lower_bound NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (lower_bound >= 0),
  upper_bound NUMERIC(14, 2) CHECK (upper_bound IS NULL OR upper_bound >= lower_bound),
  -- Flat PT amount for the band (per month). Fully employee-borne.
  amount NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (amount >= 0),
  -- Month override 1..12 for a state's special month (e.g. a higher February slab);
  -- NULL = applies to every month.
  month SMALLINT CHECK (month IS NULL OR (month >= 1 AND month <= 12)),
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- One slab per state per lower-bound per month. COALESCE(month, 0) collapses the
-- month-agnostic default (NULL) to 0 so two "every month" slabs for the same band
-- DO conflict (Postgres would otherwise treat the NULLs as distinct). This
-- expression index is the conflict target the repo's upsert names.
CREATE UNIQUE INDEX IF NOT EXISTS uq_statutory_pt_slabs_band
  ON statutory_pt_slabs (organization_id, school_id, state, lower_bound, COALESCE(month, 0));

CREATE INDEX IF NOT EXISTS idx_statutory_pt_slabs_state
  ON statutory_pt_slabs (school_id, state, active);

CREATE TRIGGER statutory_pt_slabs_updated_at
  BEFORE UPDATE ON statutory_pt_slabs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE statutory_pt_slabs ENABLE ROW LEVEL SECURITY;
ALTER TABLE statutory_pt_slabs FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS statutory_pt_slabs_school_scope ON statutory_pt_slabs;
CREATE POLICY statutory_pt_slabs_school_scope ON statutory_pt_slabs
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

GRANT SELECT, INSERT, UPDATE ON statutory_pt_slabs TO erp_tenant;

-- ── 3. Per-run per-component statutory liability (posted on run PROCESS) ────────
CREATE TABLE IF NOT EXISTS payroll_statutory_liabilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- Payroll runs are JSONB-snapshot rows keyed by a free-form TEXT id, not a UUID.
  payroll_run_id TEXT NOT NULL,
  period TEXT NOT NULL DEFAULT '',
  component TEXT NOT NULL CHECK (component IN ('pf', 'esi', 'pt', 'tds')),
  state TEXT NOT NULL DEFAULT '',
  -- employee = Σ withheld from employees; employer = Σ employer contribution;
  -- total = the remittance owed to the authority (PT/TDS = employee only).
  employee_amount NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (employee_amount >= 0),
  employer_amount NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (employer_amount >= 0),
  total_amount NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  employee_count INTEGER NOT NULL DEFAULT 0 CHECK (employee_count >= 0),
  -- Liability record only (no cash movement). 'reversed' reserved for a future
  -- correction flow; liabilities are never deleted.
  status TEXT NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
  posted_by UUID REFERENCES users (id),
  posted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- Idempotency: one liability row per run per component per jurisdiction.
  UNIQUE (organization_id, school_id, payroll_run_id, component, state)
);

CREATE INDEX IF NOT EXISTS idx_payroll_statutory_liabilities_run
  ON payroll_statutory_liabilities (school_id, payroll_run_id);

CREATE INDEX IF NOT EXISTS idx_payroll_statutory_liabilities_component
  ON payroll_statutory_liabilities (school_id, component, status);

CREATE TRIGGER payroll_statutory_liabilities_updated_at
  BEFORE UPDATE ON payroll_statutory_liabilities
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE payroll_statutory_liabilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_statutory_liabilities FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payroll_statutory_liabilities_school_scope ON payroll_statutory_liabilities;
CREATE POLICY payroll_statutory_liabilities_school_scope ON payroll_statutory_liabilities
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

-- SELECT/INSERT/UPDATE (the ON CONFLICT DO NOTHING post + a future reversal UPDATE);
-- never DELETE — liabilities are permanent.
GRANT SELECT, INSERT, UPDATE ON payroll_statutory_liabilities TO erp_tenant;
