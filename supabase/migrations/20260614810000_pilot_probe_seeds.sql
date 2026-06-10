-- Pilot operations tenant isolation probe seeds (School A / School B)

INSERT INTO attendance_sessions (
  id, organization_id, school_id, class_label, taken_by, status
) VALUES (
  'd3000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  '9-B', 'a3000000-0000-4000-8000-000000000001', 'submitted'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO timetable_slots (
  id, organization_id, school_id, class_label, day_of_week, period_number, subject_label
) VALUES (
  'd4000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  '9-B', 1, 1, 'Science'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO mobile_leave_requests (
  id, organization_id, school_id, requester_user_id, requester_scope,
  from_date_label, to_date_label, reason
) VALUES (
  'd5000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000003',
  'parent', '10 Jun', '11 Jun', 'Probe leave A'
), (
  'd5000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'a3000000-0000-4000-8000-000000000003',
  'parent', '10 Jun', '11 Jun', 'Probe leave B'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO homework_submissions (
  id, organization_id, school_id, student_id, homework_id, notes
) VALUES (
  'd6000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  'hw_probe_a', 'Probe submission A'
), (
  'd6000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'a4000000-0000-4000-8000-000000000002',
  'hw_probe_b', 'Probe submission B'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO exam_mark_entries (
  id, organization_id, school_id, student_id, exam_id, exam_title, class_label,
  marks_obtained, max_marks
) VALUES (
  'mark_probe_a',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  'exam_probe', 'Probe Exam', '8-A', 10, 50
), (
  'mark_probe_b',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'a4000000-0000-4000-8000-000000000002',
  'exam_probe', 'Probe Exam', '9-B', 5, 50
) ON CONFLICT (id) DO NOTHING;

INSERT INTO attendance_sessions (
  id, organization_id, school_id, class_label, taken_by, status
) VALUES (
  'd3000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  '8-A', 'a3000000-0000-4000-8000-000000000001', 'submitted'
) ON CONFLICT (id) DO NOTHING;
