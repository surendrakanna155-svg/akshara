-- W4 (Owner decision #12, FINAL) — Organization Device / Asset management.
--
-- Assign a physical device / asset (laptop, tablet, projector, printer, …) to a
-- staff member and track its lifecycle:
--
--     in_stock ──assign──▶ assigned ──return──▶ returned ──assign──▶ assigned …
--        │                    │                    │
--        └──retire/lost──▶ retired / lost ◀──lost──┘   (retired / lost are terminal)
--
-- WHY A NEW MODULE (not the inventory register): the existing inventory module
-- (inventory_stock_valuations / stock_movements) models FUNGIBLE stock — a per-SKU
-- quantity_on_hand with weighted-average cost and reorder levels. It has an
-- `item_type = 'asset'` flag but NO per-unit identity: no serial, no assignee, no
-- lifecycle. You cannot say "asset LAP-0007 is with staff X and came back damaged".
-- Device/asset ASSIGNMENT + LIFECYCLE is an instance-level concern, so it gets its
-- own two-table model — the SAME shape as the SIS TC / library accession register:
-- a register table whose status transitions are guarded, plus an append-only
-- assignment ledger that preserves every custody episode.
--
-- SHAPE — two tables:
--
--   1. org_assets — the asset register: one row per physical asset instance
--      (asset tag, type, serial, purchase ref/cost, current status, current
--      assignee). Status transitions are GUARDED with the money-integrity
--      throw-on-0-rows pattern (WHERE status = ANY(<allowed-from>)): a concurrent
--      double-assign serializes on the row lock — the first flips in_stock/returned
--      -> assigned, the second matches 0 rows and is rejected. Never race-prone.
--
--   2. device_assignments — the append-only custody ledger: one row per assignment
--      EPISODE (assigned_to, assigned_at, returned_at, condition, note). A new
--      assignment ALWAYS inserts a fresh row — history is NEVER overwritten. The
--      ONLY update is closing the open episode on return (setting returned_at +
--      condition on the row whose returned_at IS NULL); a past custody row is never
--      mutated and no row is ever deleted. Hence SELECT/INSERT/UPDATE grant, NO
--      DELETE — identical to library_accession_register.
--
-- School-scope FORCE RLS + grant mirror library_accession_register / expense_ledger
-- (app_current_scope() = 'school'). RBAC reuses the existing inventory-management
-- permission slugs (manageInventory to write, viewInventory to read) — an org asset
-- register is an inventory / store concern (role `inventoryManager` already holds
-- them). Migration 20260900000029 is the slot assigned for this module, clear of
-- the …020–026 band already in use and the 20260877–20260890 PRC band.
--
-- Idempotent: CREATE ... IF NOT EXISTS, DROP/CREATE for triggers/policies.

-- ─── 1. Asset register — one row per physical asset instance ─────────────────

CREATE TABLE IF NOT EXISTS org_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- Human-facing asset tag (e.g. "LAP-0007"). Unique per (org, school).
  asset_tag TEXT NOT NULL CHECK (length(trim(asset_tag)) > 0),
  -- Free-but-non-empty asset type (laptop, tablet, projector, printer, router …).
  asset_type TEXT NOT NULL CHECK (length(trim(asset_type)) > 0),
  -- Manufacturer serial number (optional, but unique per (org, school) when set).
  serial_no TEXT,
  -- Purchase provenance: a free-form PO / invoice / GRN reference and the cost.
  purchase_ref TEXT,
  purchase_cost NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (purchase_cost >= 0),
  -- Lifecycle state. in_stock / returned are the "available" states from which an
  -- asset may be assigned; retired / lost are terminal.
  status TEXT NOT NULL DEFAULT 'in_stock'
    CHECK (status IN ('in_stock', 'assigned', 'returned', 'retired', 'lost')),
  -- The staff member currently holding the asset (NULL unless status = 'assigned').
  current_assignee TEXT,
  note TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- An asset tag is unique per library/school register (the human key), and a serial
-- number, when present, is unique too (no two rows for the same physical unit).
CREATE UNIQUE INDEX IF NOT EXISTS uq_org_assets_tag
  ON org_assets (organization_id, school_id, asset_tag);
CREATE UNIQUE INDEX IF NOT EXISTS uq_org_assets_serial
  ON org_assets (organization_id, school_id, serial_no)
  WHERE serial_no IS NOT NULL;

-- List-by-status (in-stock pool, assigned register, retired/lost rollups) and
-- list-by-current-assignee (a staff member's kit) are the two hot read paths.
CREATE INDEX IF NOT EXISTS idx_org_assets_status
  ON org_assets (organization_id, school_id, status);
CREATE INDEX IF NOT EXISTS idx_org_assets_assignee
  ON org_assets (organization_id, school_id, current_assignee)
  WHERE current_assignee IS NOT NULL;

DROP TRIGGER IF EXISTS org_assets_updated_at ON org_assets;
CREATE TRIGGER org_assets_updated_at
  BEFORE UPDATE ON org_assets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE org_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_assets FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS org_assets_school_scope ON org_assets;
CREATE POLICY org_assets_school_scope ON org_assets
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

-- An asset is registered (INSERT) and its status transitions (UPDATE). It is
-- retired / lost, never physically deleted — the register record is permanent.
-- Hence NO DELETE grant.
GRANT SELECT, INSERT, UPDATE ON org_assets TO erp_tenant;

-- ─── 2. Custody ledger — append-only, one row per assignment episode ─────────

CREATE TABLE IF NOT EXISTS device_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  asset_id UUID NOT NULL REFERENCES org_assets (id),
  -- The staff member this episode assigned the asset to (immutable for the row).
  assigned_to TEXT NOT NULL CHECK (length(trim(assigned_to)) > 0),
  assigned_by UUID,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- Filled ONLY when the episode is closed on return. NULL = the OPEN episode.
  returned_at TIMESTAMPTZ,
  -- Condition recorded at return (e.g. good / damaged / needs_repair). NULL until
  -- returned.
  condition TEXT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- At most ONE open (un-returned) episode per asset — the DB backstop for the
-- status guard: even under a race, an asset cannot have two concurrent custodians.
CREATE UNIQUE INDEX IF NOT EXISTS uq_device_assignments_open
  ON device_assignments (organization_id, school_id, asset_id)
  WHERE returned_at IS NULL;

-- Per-asset history (custody timeline) and per-staff assigned list are the hot
-- read paths.
CREATE INDEX IF NOT EXISTS idx_device_assignments_asset
  ON device_assignments (organization_id, school_id, asset_id, assigned_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_assignments_staff
  ON device_assignments (organization_id, school_id, assigned_to);

ALTER TABLE device_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_assignments FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS device_assignments_school_scope ON device_assignments;
CREATE POLICY device_assignments_school_scope ON device_assignments
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

-- APPEND-ONLY custody ledger. Each assign INSERTs a new episode; the ONLY UPDATE
-- is closing the open episode on return (returned_at + condition). A past custody
-- row is never rewritten and no row is ever deleted — history is preserved.
-- Hence SELECT/INSERT/UPDATE, NO DELETE.
GRANT SELECT, INSERT, UPDATE ON device_assignments TO erp_tenant;
