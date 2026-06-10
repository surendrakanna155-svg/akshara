import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const PROBES_PATH = new URL("../tenant_isolation_probes.ts", import.meta.url);
const probesSource = await Deno.readTextFile(PROBES_PATH);

const SIS_PHASE_5A0_PROBES = [
  "school_a_cannot_see_school_b_students",
  "organization_denied_student_profiles",
  "parent_denied_student_profiles",
  "student_denied_student_profiles",
  "school_a_cannot_see_school_b_student_profiles",
  "school_a_sees_own_student_profiles",
  "organization_denied_sis_enrollments",
  "parent_denied_sis_enrollments",
  "student_denied_sis_enrollments",
  "school_a_cannot_see_school_b_sis_enrollments",
  "school_a_sees_own_sis_enrollments",
] as const;

const SIS_PHASE_5A1_PROBES = [
  "organization_denied_sis_students_api",
  "parent_denied_sis_students_api",
  "student_denied_sis_students_api",
  "school_a_cannot_fetch_school_b_student_detail",
] as const;

const SIS_PHASE_5A2_PROBES = [
  "organization_denied_sis_student_create",
  "parent_denied_sis_student_create",
  "student_denied_sis_student_create",
  "school_a_cannot_update_school_b_student",
] as const;

const SIS_PHASE_5A3_PROBES = [
  "organization_denied_sis_enrollments_api",
  "parent_denied_sis_enrollments_api",
  "student_denied_sis_enrollments_api",
  "school_a_cannot_update_school_b_enrollment",
] as const;

const SIS_PHASE_5A4_PROBES = [
  "organization_denied_admissions_conversion",
  "parent_denied_admissions_conversion",
  "student_denied_admissions_conversion",
  "school_a_cannot_convert_school_b_enrollment",
  "school_a_cannot_see_school_b_converted_enrollment",
] as const;

const SIS_PHASE_5B_PROBES = [
  "organization_denied_sis_dashboard",
  "parent_denied_sis_dashboard",
  "student_denied_sis_dashboard",
  "school_a_sees_own_sis_dashboard",
] as const;

const ACADEMIC_PHASE_5C_PROBE_COUNT = 20;
const ACADEMIC_PHASE_5C0B_PROBE_COUNT = 16;

const BASELINE_PROBE_COUNT = 53;
const EXPECTED_PROBE_COUNT = BASELINE_PROBE_COUNT +
  SIS_PHASE_5A0_PROBES.length +
  SIS_PHASE_5A1_PROBES.length +
  SIS_PHASE_5A2_PROBES.length +
  SIS_PHASE_5A3_PROBES.length +
  SIS_PHASE_5A4_PROBES.length +
  SIS_PHASE_5B_PROBES.length +
  ACADEMIC_PHASE_5C_PROBE_COUNT +
  ACADEMIC_PHASE_5C0B_PROBE_COUNT;

function extractProbeNames(source: string): string[] {
  const names: string[] = [];
  const pattern = /name:\s*"([^"]+)"/g;
  for (const match of source.matchAll(pattern)) {
    names.push(match[1]!);
  }
  return names;
}

Deno.test("SIS 5A0 isolation probes are registered", () => {
  for (const probe of SIS_PHASE_5A0_PROBES) {
    assert(
      probesSource.includes(`name: "${probe}"`),
      `missing probe: ${probe}`,
    );
  }
});

Deno.test("SIS 5A0 probe fixture UUIDs are defined", () => {
  for (const fixture of [
    "STUDENT_PROFILE_SCHOOL_A",
    "STUDENT_PROFILE_SCHOOL_B",
    "SIS_ENROLLMENT_SCHOOL_A",
    "SIS_ENROLLMENT_SCHOOL_B",
  ]) {
    assert(probesSource.includes(fixture), `missing fixture constant: ${fixture}`);
  }
});

Deno.test("SIS 5A1 isolation probes are registered", () => {
  for (const probe of SIS_PHASE_5A1_PROBES) {
    assert(
      probesSource.includes(`name: "${probe}"`),
      `missing probe: ${probe}`,
    );
  }
});

Deno.test("SIS 5A2 isolation probes are registered", () => {
  for (const probe of SIS_PHASE_5A2_PROBES) {
    assert(
      probesSource.includes(`name: "${probe}"`),
      `missing probe: ${probe}`,
    );
  }
});

Deno.test("SIS 5A3 isolation probes are registered", () => {
  for (const probe of SIS_PHASE_5A3_PROBES) {
    assert(
      probesSource.includes(`name: "${probe}"`),
      `missing probe: ${probe}`,
    );
  }
});

Deno.test("SIS 5A4 isolation probes are registered", () => {
  for (const probe of SIS_PHASE_5A4_PROBES) {
    assert(
      probesSource.includes(`name: "${probe}"`),
      `missing probe: ${probe}`,
    );
  }
});

Deno.test("SIS 5B dashboard probes are registered", () => {
  for (const probe of SIS_PHASE_5B_PROBES) {
    assert(
      probesSource.includes(`name: "${probe}"`),
      `missing probe: ${probe}`,
    );
  }
});

Deno.test("tenant isolation probe count reaches 5C.0b target", () => {
  const names = extractProbeNames(probesSource);
  assertEquals(names.length, EXPECTED_PROBE_COUNT, `probes: ${names.join(", ")}`);
});

Deno.test("SIS 5A0 probes query operational tables only", () => {
  assert(probesSource.includes("FROM student_profiles"));
  assert(probesSource.includes("FROM sis_student_enrollments"));
});

Deno.test("SIS conversion probes query admissions_enrollments", async () => {
  const conversionSource = await Deno.readTextFile(
    new URL("./sis_conversion_repository.ts", import.meta.url),
  );
  assert(conversionSource.includes("FROM admissions_enrollments"));
  assert(probesSource.includes("organization_denied_admissions_conversion"));
});
