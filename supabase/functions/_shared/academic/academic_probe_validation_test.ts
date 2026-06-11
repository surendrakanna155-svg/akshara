import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const PROBES_PATH = new URL("../tenant_isolation_probes.ts", import.meta.url);
const probesSource = await Deno.readTextFile(PROBES_PATH);

const ACADEMIC_PHASE_5C0A_PROBES = [
  "organization_denied_academic_years",
  "parent_denied_academic_years",
  "student_denied_academic_years",
  "school_a_cannot_see_school_b_academic_years",
  "school_a_sees_own_academic_years",
  "organization_denied_academic_classes",
  "parent_denied_academic_classes",
  "student_denied_academic_classes",
  "school_a_cannot_see_school_b_academic_classes",
  "school_a_sees_own_academic_classes",
  "organization_denied_academic_sections",
  "parent_denied_academic_sections",
  "student_denied_academic_sections",
  "school_a_cannot_see_school_b_academic_sections",
  "school_a_sees_own_academic_sections",
  "organization_denied_academic_teacher_assignments",
  "parent_denied_academic_teacher_assignments",
  "student_denied_academic_teacher_assignments",
  "school_a_cannot_see_school_b_academic_teacher_assignments",
  "school_a_sees_own_academic_teacher_assignments",
] as const;

const ACADEMIC_PHASE_5C0B_PROBES = [
  "organization_denied_academic_years_api",
  "parent_denied_academic_years_api",
  "student_denied_academic_years_api",
  "school_a_cannot_fetch_school_b_academic_year",
  "organization_denied_academic_classes_api",
  "parent_denied_academic_classes_api",
  "student_denied_academic_classes_api",
  "school_a_cannot_fetch_school_b_class",
  "organization_denied_academic_sections_api",
  "parent_denied_academic_sections_api",
  "student_denied_academic_sections_api",
  "school_a_cannot_fetch_school_b_section",
  "organization_denied_academic_teacher_assignments_api",
  "parent_denied_academic_teacher_assignments_api",
  "student_denied_academic_teacher_assignments_api",
  "school_a_cannot_fetch_school_b_teacher_assignment",
] as const;

const EXPECTED_PROBE_COUNT = 219;

function extractProbeNames(source: string): string[] {
  const names: string[] = [];
  const pattern = /name:\s*"([^"]+)"/g;
  for (const match of source.matchAll(pattern)) {
    names.push(match[1]!);
  }
  return names;
}

Deno.test("Academic 5C.0a isolation probes are registered", () => {
  for (const probe of ACADEMIC_PHASE_5C0A_PROBES) {
    assert(
      probesSource.includes(`name: "${probe}"`),
      `missing probe: ${probe}`,
    );
  }
});

Deno.test("Academic 5C.0b API isolation probes are registered", () => {
  for (const probe of ACADEMIC_PHASE_5C0B_PROBES) {
    assert(
      probesSource.includes(`name: "${probe}"`),
      `missing probe: ${probe}`,
    );
  }
});

Deno.test("Academic probe fixture UUIDs are defined in repositories", () => {
  for (const fixture of [
    "ACADEMIC_YEAR_SCHOOL_A",
    "ACADEMIC_YEAR_SCHOOL_B",
    "ACADEMIC_CLASS_SCHOOL_A",
    "ACADEMIC_CLASS_SCHOOL_B",
    "ACADEMIC_SECTION_SCHOOL_A",
    "ACADEMIC_SECTION_SCHOOL_B",
    "ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A",
    "ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B",
  ]) {
    assert(probesSource.includes(fixture), `missing fixture constant: ${fixture}`);
  }
});

Deno.test("Academic probes import operational and API SQL constants", () => {
  assert(probesSource.includes("ACADEMIC_YEARS_PROBE_SQL"));
  assert(probesSource.includes("ACADEMIC_YEARS_API_PROBE_SQL"));
  assert(probesSource.includes("ACADEMIC_YEAR_DETAIL_PROBE_SQL"));
  assert(probesSource.includes("ACADEMIC_CLASSES_API_PROBE_SQL"));
  assert(probesSource.includes("ACADEMIC_CLASS_DETAIL_PROBE_SQL"));
  assert(probesSource.includes("ACADEMIC_SECTIONS_API_PROBE_SQL"));
  assert(probesSource.includes("ACADEMIC_SECTION_DETAIL_PROBE_SQL"));
  assert(probesSource.includes("ACADEMIC_TEACHER_ASSIGNMENTS_API_PROBE_SQL"));
  assert(probesSource.includes("ACADEMIC_TEACHER_ASSIGNMENT_DETAIL_PROBE_SQL"));
});

Deno.test("tenant isolation probe count reaches v7.6 target (213)", () => {
  const names = extractProbeNames(probesSource);
  const duplicates = names.filter((name, index) => names.indexOf(name) !== index);
  assertEquals(duplicates.length, 0, `duplicate probes: ${duplicates.join(", ")}`);
  assertEquals(names.length, EXPECTED_PROBE_COUNT, `probes: ${names.join(", ")}`);
});

Deno.test("Academic probes query academic foundation tables", () => {
  assert(probesSource.includes("FROM academic_years"));
  assert(probesSource.includes("FROM classes"));
  assert(probesSource.includes("FROM sections"));
  assert(probesSource.includes("FROM teacher_assignments"));
});
