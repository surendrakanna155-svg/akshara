import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeSubjectWorkload,
  SubjectAssignmentValidationError,
  type TeacherSubjectAssignmentRow,
} from "./subject_assignments_repository.ts";

Deno.test("computeSubjectWorkload aggregates periods and flags overload", () => {
  const rows: TeacherSubjectAssignmentRow[] = [
    {
      id: "1",
      organization_id: "o",
      school_id: "s",
      academic_year_id: "y",
      teacher_user_id: "t1",
      subject_id: "sub1",
      class_id: null,
      section_id: null,
      periods_per_week: 15,
      is_primary: true,
      status: "active",
      created_at: "",
      updated_at: "",
    },
    {
      id: "2",
      organization_id: "o",
      school_id: "s",
      academic_year_id: "y",
      teacher_user_id: "t1",
      subject_id: "sub1",
      class_id: "c2",
      section_id: null,
      periods_per_week: 12,
      is_primary: false,
      status: "active",
      created_at: "",
      updated_at: "",
    },
  ];
  const workload = computeSubjectWorkload(rows, 25);
  assertEquals(workload.length, 1);
  assertEquals(workload[0]!.totalPeriods, 27);
  assertEquals(workload[0]!.isOverloaded, true);
});

Deno.test("SubjectAssignmentValidationError has correct name", () => {
  const err = new SubjectAssignmentValidationError("duplicate");
  assertEquals(err.name, "SubjectAssignmentValidationError");
  assertThrows(() => {
    throw err;
  }, SubjectAssignmentValidationError);
});
