-- v6.1 Sprint 5C.2a — Soft academic catalog FK linkage (operational tables)
-- Nullable FK columns; TEXT columns retained; ON DELETE SET NULL

-- ─── sis_student_enrollments ─────────────────────────────────────────────────

ALTER TABLE sis_student_enrollments
  ADD COLUMN IF NOT EXISTS academic_year_id UUID
    REFERENCES academic_years (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS class_id UUID
    REFERENCES classes (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS section_id UUID
    REFERENCES sections (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_sis_enrollments_school_year_id
  ON sis_student_enrollments (school_id, academic_year_id);

CREATE INDEX IF NOT EXISTS idx_sis_enrollments_school_class_id
  ON sis_student_enrollments (school_id, class_id);

CREATE INDEX IF NOT EXISTS idx_sis_enrollments_school_section_id
  ON sis_student_enrollments (school_id, section_id);

-- ─── admissions_enrollments ──────────────────────────────────────────────────

ALTER TABLE admissions_enrollments
  ADD COLUMN IF NOT EXISTS academic_year_id UUID
    REFERENCES academic_years (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS class_id UUID
    REFERENCES classes (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS section_id UUID
    REFERENCES sections (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_admissions_enrollments_school_year_id
  ON admissions_enrollments (school_id, academic_year_id);

CREATE INDEX IF NOT EXISTS idx_admissions_enrollments_school_class_id
  ON admissions_enrollments (school_id, class_id);

CREATE INDEX IF NOT EXISTS idx_admissions_enrollments_school_section_id
  ON admissions_enrollments (school_id, section_id);

-- ─── finance_fee_structures ──────────────────────────────────────────────────

ALTER TABLE finance_fee_structures
  ADD COLUMN IF NOT EXISTS academic_year_id UUID
    REFERENCES academic_years (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_finance_fee_structures_school_year_id
  ON finance_fee_structures (school_id, academic_year_id);
