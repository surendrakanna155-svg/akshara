-- v6.1 Sprint 4 Phase 5A4 — Admissions conversion bridge
-- Tracks conversion audit columns + concurrency hardening + probe fixtures

ALTER TABLE admissions_enrollments
  ADD COLUMN IF NOT EXISTS converted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS converted_by UUID REFERENCES users (id);

-- At most one current enrollment per student (race-safe single-current invariant)
CREATE UNIQUE INDEX IF NOT EXISTS idx_sis_enrollments_one_current_per_student
  ON sis_student_enrollments (student_id)
  WHERE is_current = true;

-- ─── Probe fixtures (School A pending + School B converted) ─────────────────

INSERT INTO admissions_enrollments (
  id,
  organization_id,
  school_id,
  student_id,
  student_name,
  seeking_class,
  section,
  academic_year,
  guardian_name,
  phone,
  gender,
  date_of_birth,
  conversion_status,
  admission_number,
  converted_at,
  converted_by
) VALUES (
  'bd000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  'Staging Student',
  '5',
  'A',
  '2026-27',
  'Staging Parent',
  '+919876543211',
  'male',
  '2014-05-15',
  'pending',
  'ADM-2026-PROBE001',
  NULL,
  NULL
),
(
  'bd000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'a4000000-0000-4000-8000-000000000002',
  'School B Student',
  '6',
  'B',
  '2026-27',
  'School B Parent',
  '+919876543212',
  'female',
  '2015-08-20',
  'converted',
  'ADM-2026-PROBE002',
  timezone('utc', now()),
  'a3000000-0000-4000-8000-000000000001'
)
ON CONFLICT (id) DO NOTHING;
