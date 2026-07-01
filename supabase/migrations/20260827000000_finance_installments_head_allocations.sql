-- FIN-6 / FIN-D2 — Installment schedule + per-head payment allocation.
--
-- Both tables are STRICTLY ADDITIVE. They layer informational / derived ledgers
-- ON TOP of the existing single-outstanding money path — they NEVER change how
-- finance_invoices.outstanding_amount or finance_student_accounts.outstanding_amount
-- are computed or updated. The invoice's single outstanding stays authoritative.
--
--   * finance_invoice_installments (FIN-6) — a term-wise DUE schedule generated at
--     invoice creation from the school's `payments.installment_terms` setting. It
--     is informational (drives reminders/display); it does NOT create multiple
--     invoices and does NOT hold money that reduces outstanding.
--   * finance_invoice_head_allocations (FIN-D2) — a self-reconciling DERIVED ledger
--     that splits the ONE invoice's paid amount across fee heads (tuition first,
--     then sort_order) as collections happen. Invariant, enforced in the repo +
--     asserted by test: SUM(head_paid) for an invoice == amount_paid
--     (= total_amount - outstanding_amount).
--
-- MONEY UNIT: amounts here are stored in the SAME NUMERIC(12,2) scale as
-- finance_invoices / finance_fee_structure_items (major rupees). This is a
-- deliberate money-safety choice — matching the invoice scale byte-for-byte makes
-- the reconciliation invariant exact (no minor-unit conversion / rounding drift).
--
-- RBAC is the existing finance gate (viewFinance to read, manageFinance to write);
-- no new permission is introduced. RLS follows the school-scope idiom used by
-- 20260823000000_finance_recovery_crm.sql. erp_tenant gets SELECT/INSERT/UPDATE
-- only (no DELETE), consistent with the rest of the finance schema.

-- FIN-6 — installment / term-wise due schedule -------------------------------
CREATE TABLE finance_invoice_installments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  invoice_id UUID NOT NULL REFERENCES finance_invoices (id),
  term_no INTEGER NOT NULL CHECK (term_no >= 1),
  due_date DATE NOT NULL,
  amount_minor NUMERIC(12, 2) NOT NULL CHECK (amount_minor >= 0),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'due', 'paid')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (invoice_id, term_no)
);

CREATE INDEX idx_invoice_installments_invoice
  ON finance_invoice_installments (organization_id, school_id, invoice_id, term_no);

ALTER TABLE finance_invoice_installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_invoice_installments FORCE ROW LEVEL SECURITY;

CREATE POLICY invoice_installments_school_read ON finance_invoice_installments
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY invoice_installments_school_insert ON finance_invoice_installments
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY invoice_installments_school_update ON finance_invoice_installments
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON finance_invoice_installments TO erp_tenant;

-- FIN-D2 — per-head payment allocation ---------------------------------------
CREATE TABLE finance_invoice_head_allocations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  invoice_id UUID NOT NULL REFERENCES finance_invoices (id),
  fee_head TEXT NOT NULL,                        -- "category:label" (or 'general:General')
  head_label TEXT NOT NULL DEFAULT '',
  head_total_minor NUMERIC(12, 2) NOT NULL CHECK (head_total_minor >= 0),
  head_paid_minor NUMERIC(12, 2) NOT NULL DEFAULT 0
    CHECK (head_paid_minor >= 0 AND head_paid_minor <= head_total_minor),
  sort_order INTEGER NOT NULL DEFAULT 0,
  priority INTEGER NOT NULL DEFAULT 0,           -- lower = allocated first (tuition = 0)
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (invoice_id, fee_head)
);

CREATE INDEX idx_invoice_head_alloc_invoice
  ON finance_invoice_head_allocations (organization_id, school_id, invoice_id, priority, sort_order);

ALTER TABLE finance_invoice_head_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_invoice_head_allocations FORCE ROW LEVEL SECURITY;

CREATE POLICY invoice_head_alloc_school_read ON finance_invoice_head_allocations
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY invoice_head_alloc_school_insert ON finance_invoice_head_allocations
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY invoice_head_alloc_school_update ON finance_invoice_head_allocations
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON finance_invoice_head_allocations TO erp_tenant;
