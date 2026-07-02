-- INV-1..7 — Store stock module: typed stock ledger, issue slips, stock counts,
-- and maker-checker adjustments for value-reducing movements.
--
-- Stock qty lives in inventory_stock_valuations.quantity_on_hand (typed INTEGER,
-- per org/school/sku). All stock-changing paths take a `SELECT quantity_on_hand
-- ... FOR UPDATE` row lock inside withTenantContext's transaction (the JSONB
-- mutateEntity lock does NOT cover this typed table). Negative stock is hard
-- blocked at the DB (CHECK) and in the repo (422). Value-reducing movements
-- (damage/wastage adjust_out, negative count variance) are RECORDED pending and
-- only decrement stock when a DIFFERENT user (checker_id <> maker_id) approves.

-- ── 1. inventory_stock_valuations — item metadata + non-negative guard + RLS fix ──

ALTER TABLE inventory_stock_valuations
  ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'asset'
    CHECK (item_type IN ('asset', 'consumable'));
ALTER TABLE inventory_stock_valuations
  ADD COLUMN IF NOT EXISTS reorder_level INTEGER NOT NULL DEFAULT 0
    CHECK (reorder_level >= 0);
ALTER TABLE inventory_stock_valuations
  ADD COLUMN IF NOT EXISTS item_name TEXT;

-- Negative stock is impossible at the storage layer (issue/adjust-out that would
-- cross zero is rejected with 422 in the repo; this CHECK is the last-line guard).
ALTER TABLE inventory_stock_valuations
  ADD CONSTRAINT quantity_on_hand_non_negative CHECK (quantity_on_hand >= 0);

-- FIX: the original inventory_stock_valuations_school policy has USING only (no
-- WITH CHECK), so a stock UPDATE/INSERT is not re-validated against the tenant/
-- school context. Mirror inv_catalog_items — DROP/CREATE with USING + WITH CHECK.
-- The scope predicate keeps the original 'school' OR 'organization' semantics.
DROP POLICY IF EXISTS inventory_stock_valuations_school ON inventory_stock_valuations;
CREATE POLICY inventory_stock_valuations_school ON inventory_stock_valuations
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

-- FORCE RLS + grants are already set on this table by 20260614920000; keep them.
ALTER TABLE inventory_stock_valuations ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_stock_valuations FORCE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON inventory_stock_valuations TO erp_tenant;

-- ── 2. stock_movements — immutable ledger (one row per stock-changing event) ──

CREATE TABLE stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  sku TEXT NOT NULL,
  movement_type TEXT NOT NULL
    CHECK (movement_type IN (
      'grn', 'issue', 'adjust_in', 'adjust_out', 'count_variance', 'opening'
    )),
  quantity_delta INTEGER NOT NULL,
  qty_before INTEGER NOT NULL CHECK (qty_before >= 0),
  qty_after INTEGER NOT NULL CHECK (qty_after >= 0),
  reason TEXT NOT NULL DEFAULT '',
  reference_id TEXT,
  reference_type TEXT,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_stock_movements_school_sku
  ON stock_movements (organization_id, school_id, sku, created_at DESC);

ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements FORCE ROW LEVEL SECURITY;

CREATE POLICY stock_movements_school ON stock_movements
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

-- Immutable ledger: SELECT + INSERT only (no UPDATE / DELETE grant).
GRANT SELECT, INSERT ON stock_movements TO erp_tenant;

-- ── 3a. stock_issues + stock_issue_lines — issue slip (posted = immutable) ──

CREATE TABLE stock_issues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  issue_number TEXT NOT NULL,
  issued_to TEXT NOT NULL DEFAULT '',
  reason TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'posted'
    CHECK (status IN ('posted', 'cancelled')),
  posted BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, issue_number)
);

CREATE TABLE stock_issue_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_issue_id UUID NOT NULL REFERENCES stock_issues (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  sku TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_cost INTEGER NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_stock_issues_school
  ON stock_issues (organization_id, school_id, created_at DESC);

-- ── 3b. stock_count_sessions + stock_count_lines — physical count (posted = immutable) ──

CREATE TABLE stock_count_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  session_number TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'posted'
    CHECK (status IN ('posted', 'cancelled')),
  posted BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, session_number)
);

CREATE TABLE stock_count_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_count_session_id UUID NOT NULL REFERENCES stock_count_sessions (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  sku TEXT NOT NULL,
  counted_qty INTEGER NOT NULL CHECK (counted_qty >= 0),
  system_qty INTEGER NOT NULL CHECK (system_qty >= 0),
  variance INTEGER NOT NULL,
  outcome TEXT NOT NULL DEFAULT 'no_change'
    CHECK (outcome IN ('no_change', 'applied_in', 'pending_adjustment')),
  adjustment_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_stock_count_sessions_school
  ON stock_count_sessions (organization_id, school_id, created_at DESC);

-- ── 3c. stock_adjustments — maker-checker for value-reducing movements ──

CREATE TABLE stock_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  sku TEXT NOT NULL,
  qty INTEGER NOT NULL CHECK (qty > 0),
  movement_type TEXT NOT NULL
    CHECK (movement_type IN ('adjust_out', 'count_variance')),
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  reference_type TEXT,
  reference_id TEXT,
  maker_id UUID REFERENCES users (id),
  checker_id UUID REFERENCES users (id),
  decision_comment TEXT,
  decided_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- SoD backstop: the checker can never be the maker (repo also enforces 409).
  CONSTRAINT stock_adjustment_checker_not_maker
    CHECK (checker_id IS NULL OR checker_id <> maker_id)
);

CREATE INDEX idx_stock_adjustments_school_status
  ON stock_adjustments (organization_id, school_id, status, created_at DESC);

CREATE TRIGGER stock_adjustments_updated_at
  BEFORE UPDATE ON stock_adjustments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── RLS (USING + WITH CHECK), FORCE, grants for the mutable tables ──

ALTER TABLE stock_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_issues FORCE ROW LEVEL SECURITY;
ALTER TABLE stock_issue_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_issue_lines FORCE ROW LEVEL SECURITY;
ALTER TABLE stock_count_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_count_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE stock_count_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_count_lines FORCE ROW LEVEL SECURITY;
ALTER TABLE stock_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_adjustments FORCE ROW LEVEL SECURITY;

CREATE POLICY stock_issues_school ON stock_issues
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY stock_issue_lines_school ON stock_issue_lines
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY stock_count_sessions_school ON stock_count_sessions
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY stock_count_lines_school ON stock_count_lines
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY stock_adjustments_school ON stock_adjustments
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

GRANT SELECT, INSERT ON stock_issues TO erp_tenant;
GRANT SELECT, INSERT ON stock_issue_lines TO erp_tenant;
GRANT SELECT, INSERT ON stock_count_sessions TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON stock_count_lines TO erp_tenant;
-- stock_adjustments: UPDATE needed for the checker decision (pending → approved/rejected).
GRANT SELECT, INSERT, UPDATE ON stock_adjustments TO erp_tenant;
