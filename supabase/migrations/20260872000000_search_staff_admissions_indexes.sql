-- Adaptive AI — P3-AI-2 / W2.S: name-prefix indexes for the Staff & Admissions
-- search categories (Universal School Search expansion).
--
-- Same fast-typeahead pattern as the students index (20260871): a
-- `lower(name) LIKE 'prefix%'` match is index-usable via text_pattern_ops,
-- scoped per school so each tenant's search touches only its own rows
-- (decision 10: 10k–100k+). Employee code already has an index via its unique
-- constraint; these close the name-prefix hot paths. Additive/dormant.

CREATE INDEX IF NOT EXISTS idx_employees_school_display_name_lower
  ON employees (school_id, lower(display_name) text_pattern_ops);

CREATE INDEX IF NOT EXISTS idx_admissions_leads_school_student_name_lower
  ON admissions_leads (school_id, lower(student_name) text_pattern_ops);
