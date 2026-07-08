import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

const PROBES_PATH = new URL("../tenant_isolation_probes.ts", import.meta.url);
const probesSource = await Deno.readTextFile(PROBES_PATH);

const PILOT_PROBES = [
  "school_a_sees_own_attendance_session_probe",
  "school_a_cannot_see_school_b_attendance_session",
  "parent_denied_attendance_session_probe",
  "school_a_sees_own_timetable_slot_probe",
  "school_a_cannot_see_school_b_timetable_slot",
  "organization_denied_timetable_slot_probe",
  "parent_a_sees_own_mobile_leave_probe",
  "parent_a_cannot_see_school_b_mobile_leave",
  "school_b_cannot_see_school_a_mobile_leave",
  "student_a_sees_own_homework_submission_probe",
  "student_a_cannot_see_school_b_homework_submission",
  "parent_denied_homework_submission_probe",
  "school_a_sees_own_exam_mark_probe",
  "school_a_cannot_see_school_b_exam_mark",
  "student_denied_exam_mark_probe",
] as const;

function extractProbeNames(source: string): string[] {
  const names: string[] = [];
  const pattern = /name:\s*"([^"]+)"/g;
  for (const match of source.matchAll(pattern)) {
    names.push(match[1]!);
  }
  return names;
}

Deno.test("Pilot 7.1 isolation probes are registered", () => {
  for (const probe of PILOT_PROBES) {
    assert(probesSource.includes(probe), `missing probe: ${probe}`);
  }
});

Deno.test("tenant isolation probe count holds the coverage floor (>=233)", () => {
  // Coverage FLOOR, not exact: probes may only be ADDED; a drop signals a removed
  // isolation guard. Was exact ==220 while the shared registry has grown to 233
  // (same stale-tripwire bug fixed for sis_probe_validation_test). Bump only when
  // adding probes.
  const count = extractProbeNames(probesSource).length;
  assert(
    count >= 233,
    `tenant-isolation coverage dropped: ${count} probes < floor 233 — an isolation guard was removed`,
  );
});
