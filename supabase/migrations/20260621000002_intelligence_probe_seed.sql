-- Tenant isolation probe fixtures for intelligence layer

INSERT INTO intel_student_risk_snapshots (
  id, organization_id, school_id, student_id,
  academic_year_label, class_name, risk_score, risk_level, reasons
) VALUES
  (
    'f0500000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    '2025-26', 'Grade 8', 72, 'high', '[]'::jsonb
  ),
  (
    'f0500000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'a4000000-0000-4000-8000-000000000002',
    '2025-26', 'Grade 9', 45, 'medium', '[]'::jsonb
  )
ON CONFLICT (id) DO NOTHING;
