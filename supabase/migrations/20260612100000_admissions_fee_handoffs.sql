-- v6.1 Sprint 3 Phase 4B0 — Admissions → Finance handoff foundation
-- Architecture: v6.1-Finance-Implementation-Mapping.md §3.4, §6

CREATE TABLE admissions_fee_handoffs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id),
  application_id UUID REFERENCES admissions_applications (id),
  enrollment_id UUID REFERENCES admissions_enrollments (id),
  academic_year TEXT NOT NULL DEFAULT '',
  recommended_fee_plan_id TEXT,
  handoff_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (handoff_status IN ('pending', 'sent_to_finance', 'completed', 'failed')),
  student_name TEXT NOT NULL,
  class_label TEXT NOT NULL DEFAULT '',
  admission_number TEXT NOT NULL DEFAULT '',
  needs_transport BOOLEAN NOT NULL DEFAULT false,
  needs_hostel BOOLEAN NOT NULL DEFAULT false,
  sis_handoff_label TEXT NOT NULL DEFAULT 'Pending finance confirmation',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_admissions_fee_handoffs_school ON admissions_fee_handoffs (school_id);
CREATE INDEX idx_admissions_fee_handoffs_student ON admissions_fee_handoffs (student_id);
CREATE INDEX idx_admissions_fee_handoffs_status ON admissions_fee_handoffs (school_id, handoff_status);

CREATE TRIGGER admissions_fee_handoffs_updated_at
  BEFORE UPDATE ON admissions_fee_handoffs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE admissions_fee_handoffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions_fee_handoffs FORCE ROW LEVEL SECURITY;

-- School staff only — no org or parent policies (TD-P0-01 / Phase 4B0 rules)
CREATE POLICY admissions_fee_handoffs_school_scope ON admissions_fee_handoffs
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

GRANT SELECT, INSERT, UPDATE ON admissions_fee_handoffs TO erp_tenant;

-- Isolation probe fixtures (School A / School B)
INSERT INTO admissions_fee_handoffs (
  id, organization_id, school_id, student_id, application_id,
  academic_year, handoff_status, student_name, class_label, admission_number
) VALUES
  (
    'b6000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    NULL,
    '2026-27',
    'pending',
    'Probe Handoff A', '5', 'ADM-PROBE-A'
  ),
  (
    'b6000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'a4000000-0000-4000-8000-000000000002',
    NULL,
    '2026-27',
    'pending',
    'Probe Handoff B', '6', 'ADM-PROBE-B'
  );
