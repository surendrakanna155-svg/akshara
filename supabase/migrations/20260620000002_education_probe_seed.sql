-- Tenant isolation probe fixtures for education suite

INSERT INTO edu_question_bank_items (
  id, organization_id, school_id, subject_name, chapter, topic,
  difficulty, question_type, marks, question_text, answer_text, status
) VALUES
  (
    'e0500000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'Mathematics', 'Algebra', 'Linear equations', 'medium', 'mcq', 2,
    'Probe question school A', 'Option B', 'active'
  ),
  (
    'e0500000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'Science', 'Physics', 'Motion', 'easy', 'short_answer', 3,
    'Probe question school B', 'Newton laws', 'active'
  )
ON CONFLICT (id) DO NOTHING;
