-- PRA-P1-34 (Owner decision #10, FINAL) — automatic leave accrual + carry-forward.
--
-- Ships the persistence for a config-driven leave-accrual engine (hr-owned):
--
--   1. leave_accrual_policies — one accrual policy PER LEAVE-TYPE per school. The
--      leave-type is a free-form TEXT ref (e.g. 'casual', 'sick', 'earned'),
--      NEVER a fixed enum — it reuses the existing leave-type vocabulary already
--      carried free-form in the HR snapshots (snapshot_leave.requests[].leaveType
--      and snapshot_settings.leavePolicy[].leaveType). A school configures its own
--      leave types; this table only stores the accrual RULES for whichever types
--      that school uses. The engine reads its rules from HERE — nothing about the
--      accrual math is hardcoded in code.
--
--   2. leave_accrual_ledger — an APPEND-ONLY ledger of accrual + deduction entries
--      per (employee, leave-type). The current balance is DERIVABLE as SUM(amount)
--      over the ledger — there is no mutable "balance" column to drift. Credits are
--      positive (opening, accrual), debits are negative (lapse, deduction). Entries
--      are never updated or deleted; a correction is a new signed 'adjustment' row.
--
-- Idempotency (no double-accrue): UNIQUE
--   (organization_id, school_id, employee_id, leave_type, entry_type, period_key)
-- backs the repo's INSERT ... ON CONFLICT DO NOTHING. Running the accrual for the
-- same employee + leave-type + period (period_key e.g. '2026-07' monthly, '2026'
-- annual, 'opening', 'lapse:2026') a second time inserts NO new row, so a re-run in
-- the same period can never double-accrue. The period_key is the guard.
--
-- Tenant isolation, RLS, grants, trigger and index all mirror the per-school
-- hr-owned payroll_finance_postings precedent (…019). Migration number
-- 20260900000024 is the next free slot in this band (…015–019 used; …020–023 are
-- reserved by sibling W-lane worktrees) and is clear of the Data-Reliability / PRC
-- 20260877–20260890 band so a later merge cannot collide.

-- ── 1. Config-driven accrual policy (per leave-type, free-form TEXT ref) ───────
CREATE TABLE IF NOT EXISTS leave_accrual_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- Free-form leave-type ref (NOT an enum). Reuses the vocabulary the school
  -- already uses in its HR leave snapshots. Never a hardcoded CHECK IN (...).
  leave_type TEXT NOT NULL,
  -- Days accrued per accrual period (per month for 'monthly', per year for
  -- 'annual'). Fractional allowed (e.g. 1.5 days/month).
  accrual_rate NUMERIC(8, 3) NOT NULL DEFAULT 0 CHECK (accrual_rate >= 0),
  -- The ONE controlled dimension that is NOT a leave-type: the accrual cadence.
  accrual_period TEXT NOT NULL DEFAULT 'monthly'
    CHECK (accrual_period IN ('monthly', 'annual')),
  -- Starting balance granted once when accrual begins for an employee.
  opening_balance NUMERIC(8, 2) NOT NULL DEFAULT 0 CHECK (opening_balance >= 0),
  -- Max days carried into the next accrual year. NULL = unlimited carry-forward.
  carry_forward_cap NUMERIC(8, 2) CHECK (carry_forward_cap IS NULL OR carry_forward_cap >= 0),
  -- Running cap on the balance during accrual. NULL = unlimited.
  max_balance NUMERIC(8, 2) CHECK (max_balance IS NULL OR max_balance >= 0),
  -- Whether the excess above the carry-forward cap is FORFEITED at year end
  -- (use-it-or-lose-it). FALSE = the full balance rolls regardless of cap.
  lapses BOOLEAN NOT NULL DEFAULT true,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- One accrual policy per leave-type per school.
  UNIQUE (organization_id, school_id, leave_type)
);

CREATE INDEX IF NOT EXISTS idx_leave_accrual_policies_school
  ON leave_accrual_policies (school_id, active);

CREATE TRIGGER leave_accrual_policies_updated_at
  BEFORE UPDATE ON leave_accrual_policies
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE leave_accrual_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_accrual_policies FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS leave_accrual_policies_school_scope ON leave_accrual_policies;
CREATE POLICY leave_accrual_policies_school_scope ON leave_accrual_policies
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

-- Policies are configured (SELECT/INSERT/UPDATE) but never deleted from code.
GRANT SELECT, INSERT, UPDATE ON leave_accrual_policies TO erp_tenant;

-- ── 2. Append-only accrual / deduction ledger (balance = SUM(amount)) ──────────
CREATE TABLE IF NOT EXISTS leave_accrual_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- Employees live as JSONB snapshot rows keyed by a free-form id (like the
  -- payroll_run_id TEXT precedent), so employee_id is TEXT, not a UUID FK.
  employee_id TEXT NOT NULL,
  -- Free-form leave-type ref (NOT an enum) — same vocabulary as the policy.
  leave_type TEXT NOT NULL,
  -- opening/accrual are credits (+); lapse/deduction are debits (−); adjustment
  -- is a signed manual correction. Balance is SUM(amount) over these rows.
  entry_type TEXT NOT NULL
    CHECK (entry_type IN ('opening', 'accrual', 'lapse', 'deduction', 'adjustment')),
  -- Signed day amount. Positive credits, negative debits.
  amount NUMERIC(8, 2) NOT NULL,
  -- The idempotency dimension: the period this entry belongs to. '2026-07' for a
  -- monthly accrual, '2026' for an annual accrual, 'opening' for the opening
  -- grant, 'lapse:2026' for a year-end lapse.
  period_key TEXT NOT NULL,
  -- The date this entry is effective (accrual as-of / deduction date).
  as_of_date DATE NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- Idempotency guard: the same employee + leave-type + entry-type + period can
  -- only ever have ONE ledger row. A re-run in the same period is a no-op.
  UNIQUE (organization_id, school_id, employee_id, leave_type, entry_type, period_key)
);

CREATE INDEX IF NOT EXISTS idx_leave_accrual_ledger_balance
  ON leave_accrual_ledger (school_id, employee_id, leave_type);

CREATE INDEX IF NOT EXISTS idx_leave_accrual_ledger_period
  ON leave_accrual_ledger (school_id, period_key);

ALTER TABLE leave_accrual_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_accrual_ledger FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS leave_accrual_ledger_school_scope ON leave_accrual_ledger;
CREATE POLICY leave_accrual_ledger_school_scope ON leave_accrual_ledger
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

-- Append-only: SELECT + INSERT only. No UPDATE, no DELETE — a correction is a new
-- signed 'adjustment' row, never an in-place edit of history.
GRANT SELECT, INSERT ON leave_accrual_ledger TO erp_tenant;
