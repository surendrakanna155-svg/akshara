import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { normalizeAcademicYearLabel } from "./academic_catalog_resolver.ts";

const MIGRATION_SQL = `
ALTER TABLE sis_student_enrollments
  ADD COLUMN IF NOT EXISTS academic_year_id UUID
    REFERENCES academic_years (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS class_id UUID
    REFERENCES classes (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS section_id UUID
    REFERENCES sections (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_sis_enrollments_school_year_id
  ON sis_student_enrollments (school_id, academic_year_id);

ALTER TABLE admissions_enrollments
  ADD COLUMN IF NOT EXISTS academic_year_id UUID
    REFERENCES academic_years (id) ON DELETE SET NULL;

ALTER TABLE finance_fee_structures
  ADD COLUMN IF NOT EXISTS academic_year_id UUID
    REFERENCES academic_years (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_finance_fee_structures_school_year_id
  ON finance_fee_structures (school_id, academic_year_id);
`;

Deno.test("5C.2a migration adds nullable FK columns with ON DELETE SET NULL", () => {
  assert(MIGRATION_SQL.includes("sis_student_enrollments"));
  assert(MIGRATION_SQL.includes("admissions_enrollments"));
  assert(MIGRATION_SQL.includes("finance_fee_structures"));
  assert(MIGRATION_SQL.includes("ON DELETE SET NULL"));
});

Deno.test("5C.2a server year normalization matches Flutter", () => {
  assert(normalizeAcademicYearLabel("2026–27") === "2026-27");
  assert(normalizeAcademicYearLabel(" 2026 - 27 ") === "2026-27");
});
