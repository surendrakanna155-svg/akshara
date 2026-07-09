-- Gap-sweep wave 2, STEP 5 — Fee reductions (scholarships + discounts) that
-- ACTUALLY reduce a student's payable, but ONLY through a two-person
-- maker-checker (mirrors the certified FIN-D4 fee-concession + refund pattern).
--
-- One unified table backs BOTH a scholarship AWARD and a discount APPLICATION
-- (source_kind discriminates; exactly one of scholarship_id / discount_rule_id
-- is set). A row is born `pending` and reduces NOTHING. Only a SECOND authorized
-- person (approver != created_by, enforced server-side) flips it to `approved`,
-- at which point the reduction is applied to the invoice + student account in
-- lockstep. Reversal (`reversed`) adds the same amount back in lockstep.
--
-- Money invariants preserved:
--   * invoice.outstanding_amount ↔ finance_student_accounts.outstanding_amount
--     move by the SAME delta (same lockstep as collect/refund/waive-late-fee).
--   * no negative payable — the applied amount is clamped to the invoice's
--     current outstanding AND total (see finance_fee_reductions_repository.ts).
--   * `applied_amount` records what was ACTUALLY applied (post-clamp), so the
--     reversal is exact and can never double-refund.

CREATE TABLE finance_fee_reductions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  -- Which built CRUD row authorised this reduction. Exactly one is set,
  -- discriminated by source_kind (see finance_fee_reductions_source_ck).
  source_kind TEXT NOT NULL CHECK (source_kind IN ('scholarship', 'discount')),
  scholarship_id UUID REFERENCES finance_scholarships (id),
  discount_rule_id UUID REFERENCES finance_discount_rules (id),

  -- WHO gets the reduction and WHERE it lands. student_id + student_account_id
  -- are resolved from the invoice at propose time (authoritative — never
  -- client-supplied) so the reduction can only ever touch the invoice's own
  -- account.
  student_id UUID NOT NULL REFERENCES students (id),
  invoice_id UUID NOT NULL REFERENCES finance_invoices (id),
  student_account_id UUID NOT NULL REFERENCES finance_student_accounts (id),

  -- amount-or-percent: exactly one of percent / fixed_amount is set.
  reduction_kind TEXT NOT NULL CHECK (reduction_kind IN ('percent', 'fixed')),
  percent NUMERIC(5, 2),
  fixed_amount NUMERIC(12, 2),

  -- What was ACTUALLY applied to the payable on approval (post-clamp). 0 until
  -- applied; drives the exact reversal.
  applied_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,

  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'reversed')),
  reason TEXT NOT NULL DEFAULT '',

  created_by UUID NOT NULL REFERENCES users (id),   -- maker (proposer)
  approved_by UUID REFERENCES users (id),           -- checker (decider)
  reversed_by UUID REFERENCES users (id),
  applied_at TIMESTAMPTZ,
  reversed_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT finance_fee_reductions_source_ck CHECK (
    (source_kind = 'scholarship'
      AND scholarship_id IS NOT NULL AND discount_rule_id IS NULL)
    OR
    (source_kind = 'discount'
      AND discount_rule_id IS NOT NULL AND scholarship_id IS NULL)
  ),
  CONSTRAINT finance_fee_reductions_value_ck CHECK (
    (reduction_kind = 'percent'
      AND percent IS NOT NULL AND percent > 0 AND percent <= 100
      AND fixed_amount IS NULL)
    OR
    (reduction_kind = 'fixed'
      AND fixed_amount IS NOT NULL AND fixed_amount > 0
      AND percent IS NULL)
  ),
  CONSTRAINT finance_fee_reductions_applied_nonneg_ck CHECK (applied_amount >= 0)
);

CREATE INDEX idx_finance_fee_reductions_org_school
  ON finance_fee_reductions (organization_id, school_id);
CREATE INDEX idx_finance_fee_reductions_invoice
  ON finance_fee_reductions (invoice_id);
CREATE INDEX idx_finance_fee_reductions_student
  ON finance_fee_reductions (student_id);
CREATE INDEX idx_finance_fee_reductions_status
  ON finance_fee_reductions (school_id, status);

-- Idempotency backstop: the SAME source (one scholarship / one discount rule)
-- cannot have two live (pending or approved) reductions against the SAME
-- invoice at once — prevents accidentally stacking the identical award twice.
-- (Distinct sources on one invoice are still allowed.)
CREATE UNIQUE INDEX uq_finance_fee_reductions_live_scholarship
  ON finance_fee_reductions (invoice_id, scholarship_id)
  WHERE scholarship_id IS NOT NULL AND status IN ('pending', 'approved');
CREATE UNIQUE INDEX uq_finance_fee_reductions_live_discount
  ON finance_fee_reductions (invoice_id, discount_rule_id)
  WHERE discount_rule_id IS NOT NULL AND status IN ('pending', 'approved');

CREATE TRIGGER finance_fee_reductions_updated_at
  BEFORE UPDATE ON finance_fee_reductions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_fee_reductions ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_fee_reductions FORCE ROW LEVEL SECURITY;

CREATE POLICY finance_fee_reductions_school_scope ON finance_fee_reductions
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

GRANT SELECT, INSERT, UPDATE ON finance_fee_reductions TO erp_tenant;
