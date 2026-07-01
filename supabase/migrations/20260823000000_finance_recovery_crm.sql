-- FIN-R3/R4/R6 — Fee-recovery / collections CRM persistence.
--
-- The defaulters screen listed who owes what but its "Last contact" column and
-- contact history were hardcoded empty (finance_defaulters_handlers lastContact:"",
-- contactHistory:[]) — there was no place to record recovery follow-up. These
-- tables are the durable, audited recovery layer:
--   * finance_recovery_contacts  — immutable log of every call/WhatsApp/SMS/visit
--     + outcome per defaulter (FIN-R4; feeds FIN-R2 call-queue history + FIN-R5
--     collector performance).
--   * finance_promises_to_pay    — promise-to-pay commitments + kept/broken
--     lifecycle (FIN-R3).
--   * finance_recovery_targets   — monthly collection targets per collector /
--     school (FIN-R6, P2).
-- All are additive — they do NOT touch the collection/invoice money path. RBAC is
-- the existing finance gate (viewFinance to read, manageFinance to write); no new
-- permission is introduced.

-- FIN-R4 — immutable contact/reminder history -------------------------------
CREATE TABLE finance_recovery_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  fee_account_id UUID,
  channel TEXT NOT NULL
    CHECK (channel IN ('call', 'whatsapp', 'sms', 'visit', 'email', 'other')),
  outcome TEXT NOT NULL
    CHECK (outcome IN ('reached', 'no_answer', 'promised', 'refused',
                       'wrong_number', 'partial_paid', 'other')),
  notes TEXT NOT NULL DEFAULT '',
  contacted_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_recovery_contacts_student
  ON finance_recovery_contacts (organization_id, school_id, student_id, created_at DESC);
CREATE INDEX idx_recovery_contacts_collector
  ON finance_recovery_contacts (organization_id, school_id, contacted_by, created_at DESC);

ALTER TABLE finance_recovery_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_recovery_contacts FORCE ROW LEVEL SECURITY;

CREATE POLICY recovery_contacts_school_read ON finance_recovery_contacts
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY recovery_contacts_school_insert ON finance_recovery_contacts
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT ON finance_recovery_contacts TO erp_tenant;

-- FIN-R3 — promise-to-pay -----------------------------------------------------
CREATE TABLE finance_promises_to_pay (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  fee_account_id UUID,
  amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
  promise_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'kept', 'broken', 'cancelled')),
  notes TEXT NOT NULL DEFAULT '',
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  resolved_by UUID,
  resolved_at TIMESTAMPTZ
);

CREATE INDEX idx_ptp_school_status
  ON finance_promises_to_pay (organization_id, school_id, status, promise_date);
CREATE INDEX idx_ptp_student
  ON finance_promises_to_pay (organization_id, school_id, student_id, created_at DESC);

ALTER TABLE finance_promises_to_pay ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_promises_to_pay FORCE ROW LEVEL SECURITY;

CREATE POLICY ptp_school_read ON finance_promises_to_pay
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY ptp_school_insert ON finance_promises_to_pay
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY ptp_school_update ON finance_promises_to_pay
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON finance_promises_to_pay TO erp_tenant;

-- FIN-R6 — monthly collection targets (P2) ------------------------------------
CREATE TABLE finance_recovery_targets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  collector_user_id UUID,                        -- NULL = school-wide target
  period_month TEXT NOT NULL,                    -- 'YYYY-MM'
  target_minor BIGINT NOT NULL CHECK (target_minor >= 0),
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, collector_user_id, period_month)
);

CREATE INDEX idx_recovery_targets_period
  ON finance_recovery_targets (organization_id, school_id, period_month);

ALTER TABLE finance_recovery_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_recovery_targets FORCE ROW LEVEL SECURITY;

CREATE POLICY recovery_targets_school_read ON finance_recovery_targets
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY recovery_targets_school_insert ON finance_recovery_targets
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY recovery_targets_school_update ON finance_recovery_targets
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON finance_recovery_targets TO erp_tenant;
