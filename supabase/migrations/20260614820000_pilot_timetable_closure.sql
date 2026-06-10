-- Pilot closure: fix timetable teacher assignments and expand demo slots

UPDATE timetable_slots
SET teacher_user_id = 'a3000000-0000-4000-8000-000000000001'
WHERE teacher_user_id = 'a3000000-0000-4000-8000-000000000004';

UPDATE comm_threads
SET teacher_user_id = 'a3000000-0000-4000-8000-000000000001'
WHERE teacher_user_id = 'a3000000-0000-4000-8000-000000000004';

INSERT INTO timetable_slots (
  organization_id, school_id, class_label, day_of_week, period_number,
  subject_label, teacher_user_id, room_label
) VALUES
  (
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    '8-A', 1, 2, 'English',
    'a3000000-0000-4000-8000-000000000001', 'Room 202'
  ),
  (
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    '8-A', 2, 1, 'Science',
    'a3000000-0000-4000-8000-000000000001', 'Lab 1'
  ),
  (
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    '8-A', 3, 1, 'Mathematics',
    'a3000000-0000-4000-8000-000000000001', 'Room 201'
  ),
  (
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    '8-A', 4, 1, 'Social Studies',
    'a3000000-0000-4000-8000-000000000001', 'Room 203'
  ),
  (
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    '8-A', 5, 1, 'Computer Science',
    'a3000000-0000-4000-8000-000000000001', 'Lab 2'
  );
