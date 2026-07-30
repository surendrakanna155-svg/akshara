-- PRC-A caps 67 + 73.
--
-- Cap 67 — a fee structure's "class range" today is free-text in
-- `finance_fee_structures.description`; there is no structural class/section
-- binding. Adds the SAME soft-FK pattern already used for
-- `finance_fee_structures.academic_year_id` (see
-- 20260618000000_academic_soft_fk.sql): nullable UUID columns referencing the
-- canonical `classes` / `sections` catalog (academic_foundation.sql), ON
-- DELETE SET NULL, indexed. Nullable = "unbound" — every existing row keeps
-- working exactly as-is (additive, backward-compatible); a bound structure
-- lets a class-wide bulk assignment resolve its students FROM the binding
-- instead of requiring an explicit studentIds[] every time.
--
-- Cap 73 — mid-year admission fee proration (owner decision #5). The POLICY
-- itself is NOT a new table — it reuses the existing finance_settings
-- key/value store (`payments.midyear_admission_proration_policy`, see
-- finance_settings_repository.ts), exactly as instructed. What DOES need
-- schema is a durable, per-assignment record of what was actually charged and
-- why, so an authorized user can see — after the fact, not just at the moment
-- of assignment — which policy applied, the month-basis derivation (months
-- charged / total months), the reference date used, the annual vs charged
-- amount, and full override provenance (actor/reason/timestamp). All columns
-- are nullable or safely defaulted so existing `finance_fee_assignments` rows
-- (all of which were, in effect, full_annual) remain valid without a backfill.

-- ─── Cap 67: class/section binding on finance_fee_structures ────────────────

ALTER TABLE finance_fee_structures
  ADD COLUMN IF NOT EXISTS class_id UUID
    REFERENCES classes (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS section_id UUID
    REFERENCES sections (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_finance_fee_structures_class_id
  ON finance_fee_structures (class_id);
CREATE INDEX IF NOT EXISTS idx_finance_fee_structures_section_id
  ON finance_fee_structures (section_id);

-- ─── Cap 73: per-assignment proration record on finance_fee_assignments ─────

ALTER TABLE finance_fee_assignments
  ADD COLUMN IF NOT EXISTS proration_policy TEXT NOT NULL DEFAULT 'full_annual'
    CHECK (proration_policy IN ('full_annual', 'prorate_from_admission_month')),
  ADD COLUMN IF NOT EXISTS proration_basis TEXT NOT NULL DEFAULT 'month'
    CHECK (proration_basis IN ('month')),
  ADD COLUMN IF NOT EXISTS proration_total_months INTEGER,
  ADD COLUMN IF NOT EXISTS proration_months_charged INTEGER,
  ADD COLUMN IF NOT EXISTS proration_reference_date DATE,
  ADD COLUMN IF NOT EXISTS proration_annual_amount NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS proration_charged_amount NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS proration_fallback_reason TEXT,
  ADD COLUMN IF NOT EXISTS proration_is_override BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS proration_override_reason TEXT,
  ADD COLUMN IF NOT EXISTS proration_overridden_by UUID
    REFERENCES users (id) ON DELETE SET NULL;

-- erp_tenant already has SELECT/INSERT/UPDATE on both tables (grants from
-- their original creation migrations) — new nullable/defaulted columns need
-- no additional GRANT and no RLS policy change (existing org+school scope
-- policies already cover the whole row).
