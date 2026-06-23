import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ACADEMIC_CLASS_SCHOOL_A,
  ACADEMIC_CLASS_SCHOOL_B,
} from "./classes_repository.ts";
import {
  ACADEMIC_SECTION_SCHOOL_A,
  ACADEMIC_SECTION_SCHOOL_B,
} from "./sections_repository.ts";
import {
  ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A,
  ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B,
} from "./teacher_assignments_repository.ts";
import {
  ACADEMIC_YEAR_SCHOOL_A,
  ACADEMIC_YEAR_SCHOOL_B,
} from "./academic_years_repository.ts";

const MIGRATION_PATH = new URL(
  "../../../migrations/20260614790000_academic_foundation.sql",
  import.meta.url,
);

const sql = await Deno.readTextFile(MIGRATION_PATH);

const FIXTURE_PAIRS: Array<[string, string]> = [
  ["ACADEMIC_YEAR_SCHOOL_A", ACADEMIC_YEAR_SCHOOL_A],
  ["ACADEMIC_YEAR_SCHOOL_B", ACADEMIC_YEAR_SCHOOL_B],
  ["ACADEMIC_CLASS_SCHOOL_A", ACADEMIC_CLASS_SCHOOL_A],
  ["ACADEMIC_CLASS_SCHOOL_B", ACADEMIC_CLASS_SCHOOL_B],
  ["ACADEMIC_SECTION_SCHOOL_A", ACADEMIC_SECTION_SCHOOL_A],
  ["ACADEMIC_SECTION_SCHOOL_B", ACADEMIC_SECTION_SCHOOL_B],
  ["ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A", ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A],
  ["ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B", ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B],
];

Deno.test("Academic fixture repository constants exist in migration SQL", () => {
  for (const [label, uuid] of FIXTURE_PAIRS) {
    assert(sql.includes(uuid), `migration missing fixture UUID for ${label}: ${uuid}`);
  }
});

Deno.test("School A fixture graph is consistent in migration", () => {
  assert(sql.includes(`'${ACADEMIC_YEAR_SCHOOL_A}'`));
  assert(sql.includes(`'${ACADEMIC_CLASS_SCHOOL_A}'`));
  assert(sql.includes(`'${ACADEMIC_SECTION_SCHOOL_A}'`));
  assert(sql.includes(`'${ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A}'`));
  assert(sql.includes(`'d1000000-0000-4000-8000-000000000001'`));
});

Deno.test("School B fixture graph is consistent in migration", () => {
  assert(sql.includes(`'${ACADEMIC_YEAR_SCHOOL_B}'`));
  assert(sql.includes(`'${ACADEMIC_CLASS_SCHOOL_B}'`));
  assert(sql.includes(`'${ACADEMIC_SECTION_SCHOOL_B}'`));
  assert(sql.includes(`'${ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B}'`));
  assert(sql.includes(`'d1000000-0000-4000-8000-000000000002'`));
});

Deno.test("Teacher users and school memberships are seeded", () => {
  assertEquals((sql.match(/INSERT INTO users/g) ?? []).length >= 1, true);
  assert(sql.includes("staging.teacher.a@aksharaerp.com"));
  assert(sql.includes("staging.teacher.b@aksharaerp.com"));
  assert(sql.includes("INSERT INTO school_memberships"));
  assert(sql.includes("'teacher'"));
});

Deno.test("School B class 6 uses distinct UUID from School A", () => {
  assert(sql.includes("cf100000-0000-4000-8000-000000000004"));
  assert(sql.includes("cf100000-0000-4000-8000-000000000002"));
});
