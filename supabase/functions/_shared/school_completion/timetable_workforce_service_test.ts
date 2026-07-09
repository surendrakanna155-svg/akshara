// P0-2 (gap-remediation wave) — timetable_workforce_service.ts unit tests.
//
// Pure day-of-week/date helpers get direct assertions. The write paths
// (assignSubstitute's slotId-parsing guard, reassignTeacherBulk's ownership
// pre-check) get an in-memory MockDb, mirroring the pattern already
// established in ../timetable/timetable_reassign_teacher_guard_test.ts for
// the underlying reassignTimetablePeriodTeacher primitive this module reuses.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  addDaysUTC,
  dayOfWeekName,
  nextOccurrenceOfWeekday,
  parseDayOfWeekName,
  reassignTeacherBulk,
  WorkforceValidationError,
} from "./timetable_workforce_service.ts";
import { assignSubstitute } from "./timetable_workforce_service.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const YEAR = "ce100000-0000-4000-8000-000000000001";
const SOURCE_TEACHER = "b0000000-0000-4000-8000-000000000001";
const OTHER_TEACHER = "b0000000-0000-4000-8000-000000000002";

// ─── Pure helpers ────────────────────────────────────────────────────────────

Deno.test("dayOfWeekName maps ISO 1..7 to Monday..Sunday", () => {
  assertEquals(dayOfWeekName(1), "Monday");
  assertEquals(dayOfWeekName(5), "Friday");
  assertEquals(dayOfWeekName(7), "Sunday");
});

Deno.test("parseDayOfWeekName is case-insensitive and rejects unknown names", () => {
  assertEquals(parseDayOfWeekName("monday"), 1);
  assertEquals(parseDayOfWeekName("FRIDAY"), 5);
  assertEquals(parseDayOfWeekName("Frunday"), null);
});

Deno.test("addDaysUTC advances calendar days across month/year boundaries", () => {
  assertEquals(addDaysUTC("2026-01-31", 1), "2026-02-01");
  assertEquals(addDaysUTC("2026-12-31", 1), "2027-01-01");
});

Deno.test("nextOccurrenceOfWeekday returns the same date when it already matches", () => {
  // 2026-07-13 is a Monday (ISO dow 1).
  assertEquals(nextOccurrenceOfWeekday("2026-07-13", 1), "2026-07-13");
  // Next Wednesday (dow 3) from a Monday is +2 days.
  assertEquals(nextOccurrenceOfWeekday("2026-07-13", 3), "2026-07-15");
});

// ─── assignSubstitute: slotId contract ──────────────────────────────────────

class ThrowingDb {
  // deno-lint-ignore require-await
  async queryObject<T>(): Promise<T[]> {
    throw new Error("MockDb should not be queried — validation must short-circuit first");
  }
}

Deno.test("assignSubstitute rejects a malformed slotId before touching the DB", async () => {
  const db = new ThrowingDb() as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      assignSubstitute(db, ORG, SCHOOL, {
        slotId: "not-a-composite-id",
        substituteTeacherId: OTHER_TEACHER,
        notifySubstituteTeacher: true,
        notifyClassIncharge: false,
        notifyStudents: false,
      }, "actor-1"),
    WorkforceValidationError,
  );
});

// ─── reassignTeacherBulk: validation + ownership guard ──────────────────────

interface Period {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year_id: string;
  teacher_id: string | null;
  timetable_id: string;
  section_id: string;
  day_of_week: number;
  period_number: number;
  subject_label: string;
  teacher_assignment_id: string | null;
  room_label: string;
  status: string;
}

class ReassignMockDb {
  updated: Array<{ id: string; teacherId: string }> = [];
  constructor(public periods: Period[]) {}

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // reassignTeacherBulk's own ownership pre-check.
    if (sql.includes("p.id, p.teacher_id") && sql.includes("p.id = ANY(")) {
      const [orgId, schoolId, yearId, ids] = args as [string, string, string, string[]];
      return this.periods
        .filter((p) =>
          p.organization_id === orgId && p.school_id === schoolId &&
          p.academic_year_id === yearId && ids.includes(p.id)
        )
        .map((p) => ({ id: p.id, teacher_id: p.teacher_id })) as T[];
    }

    // reassignTimetablePeriodTeacher: load current period + parent timetable.
    if (sql.includes("t.status, t.section_id") && sql.includes("WHERE p.id = $1")) {
      const [id, orgId, schoolId] = args as string[];
      const p = this.periods.find(
        (x) => x.id === id && x.organization_id === orgId && x.school_id === schoolId,
      );
      if (!p) return [] as T[];
      return [{
        id: p.id,
        timetable_id: p.timetable_id,
        academic_year_id: p.academic_year_id,
        status: p.status,
        section_id: p.section_id,
        day_of_week: p.day_of_week,
        period_number: p.period_number,
        subject_label: p.subject_label,
        teacher_id: p.teacher_id,
        teacher_assignment_id: p.teacher_assignment_id,
        room_label: p.room_label,
      }] as T[];
    }

    // loadSchoolPeriodsWithMeta (clash re-check).
    if (sql.includes("FROM academic_timetable_periods p") && sql.includes("t.status <> 'archived'")) {
      const [orgId, schoolId, yearId] = args as string[];
      return this.periods
        .filter((p) =>
          p.organization_id === orgId && p.school_id === schoolId &&
          p.academic_year_id === yearId && p.status !== "archived"
        )
        .map((p) => ({
          timetable_id: p.timetable_id,
          section_id: p.section_id,
          day_of_week: p.day_of_week,
          period_number: p.period_number,
          subject_label: p.subject_label,
          teacher_id: p.teacher_id,
          teacher_assignment_id: p.teacher_assignment_id,
          room_label: p.room_label,
        })) as T[];
    }

    // The actual reassign write.
    if (sql.includes("UPDATE academic_timetable_periods") && sql.includes("SET teacher_id = $4")) {
      const [id, _org, _school, teacherId] = args as [string, string, string, string];
      const p = this.periods.find((x) => x.id === id)!;
      p.teacher_id = teacherId;
      this.updated.push({ id, teacherId });
      return [{
        id: p.id,
        timetable_id: p.timetable_id,
        day_of_week: p.day_of_week,
        period_number: p.period_number,
        subject_label: p.subject_label,
        teacher_id: p.teacher_id,
        teacher_assignment_id: p.teacher_assignment_id,
        room_label: p.room_label,
      }] as T[];
    }

    throw new Error(`Unhandled SQL in ReassignMockDb: ${sql.slice(0, 80)}`);
  }
}

function period(over: Partial<Period> = {}): Period {
  return {
    id: "p1",
    organization_id: ORG,
    school_id: SCHOOL,
    academic_year_id: YEAR,
    teacher_id: SOURCE_TEACHER,
    timetable_id: "tt-a",
    section_id: "sec-a",
    day_of_week: 1,
    period_number: 1,
    subject_label: "Math",
    teacher_assignment_id: "ta-1",
    room_label: "Room 8A",
    status: "validated",
    ...over,
  };
}

function asDb(mock: ReassignMockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("reassignTeacherBulk rejects an empty slotIds array without hitting the DB", async () => {
  const mock = new ReassignMockDb([]);
  await assertRejects(
    () =>
      reassignTeacherBulk(asDb(mock), ORG, SCHOOL, {
        academicYearId: YEAR,
        sourceTeacherId: SOURCE_TEACHER,
        targetTeacherId: OTHER_TEACHER,
        slotIds: [],
        notifySourceTeacher: false,
        notifyTargetTeacher: false,
        notifyStudents: false,
      }),
    WorkforceValidationError,
  );
});

Deno.test("reassignTeacherBulk rejects sourceTeacherId === targetTeacherId", async () => {
  const mock = new ReassignMockDb([period()]);
  await assertRejects(
    () =>
      reassignTeacherBulk(asDb(mock), ORG, SCHOOL, {
        academicYearId: YEAR,
        sourceTeacherId: SOURCE_TEACHER,
        targetTeacherId: SOURCE_TEACHER,
        slotIds: ["p1"],
        notifySourceTeacher: false,
        notifyTargetTeacher: false,
        notifyStudents: false,
      }),
    WorkforceValidationError,
  );
});

Deno.test("reassignTeacherBulk rejects a slot not currently taught by sourceTeacherId (409)", async () => {
  const mock = new ReassignMockDb([period({ id: "p1", teacher_id: OTHER_TEACHER })]);
  const error = await assertRejects(
    () =>
      reassignTeacherBulk(asDb(mock), ORG, SCHOOL, {
        academicYearId: YEAR,
        sourceTeacherId: SOURCE_TEACHER,
        targetTeacherId: OTHER_TEACHER,
        slotIds: ["p1"],
        notifySourceTeacher: false,
        notifyTargetTeacher: false,
        notifyStudents: false,
      }),
    WorkforceValidationError,
  );
  assertEquals((error as WorkforceValidationError).httpStatus, 409);
  assertEquals(mock.updated.length, 0);
});

Deno.test("reassignTeacherBulk rejects an unknown slotId (404)", async () => {
  const mock = new ReassignMockDb([period({ id: "p1" })]);
  const error = await assertRejects(
    () =>
      reassignTeacherBulk(asDb(mock), ORG, SCHOOL, {
        academicYearId: YEAR,
        sourceTeacherId: SOURCE_TEACHER,
        targetTeacherId: OTHER_TEACHER,
        slotIds: ["missing"],
        notifySourceTeacher: false,
        notifyTargetTeacher: false,
        notifyStudents: false,
      }),
    WorkforceValidationError,
  );
  assertEquals((error as WorkforceValidationError).httpStatus, 404);
});

Deno.test("reassignTeacherBulk reassigns every owned slot and echoes the requested notify flags", async () => {
  const mock = new ReassignMockDb([
    period({ id: "p1", day_of_week: 1, period_number: 1 }),
    period({ id: "p2", day_of_week: 2, period_number: 2 }),
  ]);
  const result = await reassignTeacherBulk(asDb(mock), ORG, SCHOOL, {
    academicYearId: YEAR,
    sourceTeacherId: SOURCE_TEACHER,
    targetTeacherId: OTHER_TEACHER,
    slotIds: ["p1", "p2"],
    notifySourceTeacher: true,
    notifyTargetTeacher: true,
    notifyStudents: false,
  });
  assertEquals(result.updatedSlotIds.sort(), ["p1", "p2"]);
  assertEquals(result.notifiedAudience, ["source_teacher", "target_teacher"]);
  assertEquals(mock.updated.length, 2);
  assertEquals(mock.periods.every((p) => p.teacher_id === OTHER_TEACHER), true);
});

Deno.test("reassignTeacherBulk rejects the whole batch when one slot would double-book the target (atomic)", async () => {
  // p1 (day1/period1) belongs to the source teacher; p_clash already has
  // OTHER_TEACHER teaching a DIFFERENT section at that exact same slot, so
  // reassigning p1 to OTHER_TEACHER introduces a new teacher clash.
  const mock = new ReassignMockDb([
    period({ id: "p1", timetable_id: "tt-a", section_id: "sec-a", day_of_week: 1, period_number: 1 }),
    period({
      id: "p_clash",
      timetable_id: "tt-b",
      section_id: "sec-b",
      day_of_week: 1,
      period_number: 1,
      teacher_id: OTHER_TEACHER,
      room_label: "Room 8B",
    }),
  ]);
  await assertRejects(
    () =>
      reassignTeacherBulk(asDb(mock), ORG, SCHOOL, {
        academicYearId: YEAR,
        sourceTeacherId: SOURCE_TEACHER,
        targetTeacherId: OTHER_TEACHER,
        slotIds: ["p1"],
        notifySourceTeacher: false,
        notifyTargetTeacher: false,
        notifyStudents: false,
      }),
  );
  assertEquals(mock.updated.length, 0);
});
