-- FIN-D4 — per-student fee concessions (two-person maker-checker ledger).
--
-- Owner decision 2026-07-01: a fee concession uses maker-checker — a maker raises
-- it, a DIFFERENT checker approves it via the Approval Center (separation of duties
-- is already enforced in approval_repository.decideApproval — requester_id !=
-- actorId), and only then is it recorded active. Previously `feeConcession`
-- approvals were audit-only: no per-student concession was ever persisted (the
-- finance_scholarships table is a program CATALOG, not a per-student grant).
--
-- This table is the durable, audited concession ledger. Applying the concession
-- amount to the student's live payable (fee-statement netting) is a follow-up: it
-- needs the concession to carry a resolved student_id / fee_assignment_id (the
-- client currently submits a free-text student name) plus the netting rules — so
-- the row keeps both the entered label and a nullable resolved student_id.

CREATE TABLE finance_fee_concessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID,                              -- resolved linkage (nullable until wired)
  student_name TEXT NOT NULL DEFAULT '',        -- as entered by the maker
  fee_account_ref TEXT NOT NULL DEFAULT '',
  amount_label TEXT NOT NULL DEFAULT '',        -- as entered (free text)
  amount_minor BIGINT,                          -- best-effort parse of amount_label
  reason TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'rejected')),
  source_approval_id TEXT,                       -- the approval request it came from
  maker_id UUID,                                 -- who raised it (approval requester)
  checker_id UUID,                               -- who approved/rejected it (decider)
  decided_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_fee_concessions_school_status
  ON finance_fee_concessions (organization_id, school_id, status, created_at DESC);
CREATE INDEX idx_fee_concessions_student
  ON finance_fee_concessions (organization_id, school_id, student_id)
  WHERE student_id IS NOT NULL;

ALTER TABLE finance_fee_concessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_fee_concessions FORCE ROW LEVEL SECURITY;

CREATE POLICY fee_concessions_school_read ON finance_fee_concessions
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY fee_concessions_school_insert ON finance_fee_concessions
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT ON finance_fee_concessions TO erp_tenant;
