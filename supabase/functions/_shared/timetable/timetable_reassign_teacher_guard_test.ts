// #4 — clash-recheck + published-immutability guards on the teacher-reassign
// write path (reassignTimetablePeriodTeacher), mirroring
// timetable_move_guard_test.ts exactly for the sibling mutation.
//
// In-memory mock TenantQueryClient. Proves: a reassignment that introduces a
// NEW teacher double-booking is rejected (TimetableClashError); a legal
// reassignment succeeds and only touches teacher_id; a reassignment on a
// PUBLISHED timetable is rejected app-side (TimetablePublishedError) even
// before the DB trigger would fire.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  reassignTimetablePeriodTeacher,
  TimetableClashError,
  TimetablePublishedError,
} from "./timetable_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const YEAR = "ce100000-0000-4000-8000-000000000001";
const TEACHER = "b0000000-0000-4000-8000-000000000001";
const OTHER_TEACHER = "b0000000-0000-4000-8000-000000000002";

interface Period {
  id: string;
  timetable_id: string;
  organization_id: string;
  school_id: string;
  day_of_week: number;
  period_number: number;
  subject_label: string;
  teacher_id: string | null;
  teacher_assignment_id: string | null;
  room_label: string;
  section_id: string;
  academic_year_id: string;
  status: string;
}

class MockDb {
  updated: Array<{ id: string; teacherId: string }> = [];
  constructor(public periods: Period[]) {}

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // reassignTimetablePeriodTeacher: load current period + parent timetable
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

    // loadSchoolPeriodsWithMeta
    if (sql.includes("FROM academic_timetable_periods p") && sql.includes("t.status <> 'archived'")) {
      const [orgId, schoolId, yearId] = args as string[];
      return this.periods
        .filter(
          (p) =>
            p.organization_id === orgId &&
            p.school_id === schoolId &&
            p.academic_year_id === yearId &&
            p.status !== "archived",
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

    // UPDATE ... RETURNING (the actual reassign write)
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

    throw new Error(`Unhandled SQL in MockDb: ${sql.slice(0, 80)}`);
  }
}

function period(over: Partial<Period> = {}): Period {
  return {
    id: "p1",
    timetable_id: "tt-a",
    organization_id: ORG,
    school_id: SCHOOL,
    day_of_week: 1,
    period_number: 1,
    subject_label: "Math",
    teacher_id: TEACHER,
    teacher_assignment_id: "ta-1",
    room_label: "Room 8A",
    section_id: "sec-a",
    academic_year_id: YEAR,
    status: "validated",
    ...over,
  };
}

function asDb(mock: MockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("reassignTimetablePeriodTeacher succeeds for a clash-free reassignment", async () => {
  const mock = new MockDb([period({ id: "p1" })]);
  const reassigned = await reassignTimetablePeriodTeacher(asDb(mock), ORG, SCHOOL, {
    periodId: "p1",
    teacherId: OTHER_TEACHER,
  });
  assertEquals(reassigned.teacherId, OTHER_TEACHER);
  // Day/period/room/subject are untouched by a teacher-only reassignment.
  assertEquals(reassigned.dayOfWeek, 1);
  assertEquals(reassigned.periodNumber, 1);
  assertEquals(reassigned.roomLabel, "Room 8A");
  assertEquals(reassigned.subjectLabel, "Math");
  assertEquals(mock.updated.length, 1);
});

Deno.test("reassignTimetablePeriodTeacher rejects a reassignment that double-books the new teacher (TIMETABLE_CLASH)", async () => {
  // OTHER_TEACHER already teaches section B at day 1 / period 1 (same slot as
  // p1). Reassigning p1 to OTHER_TEACHER creates a NEW teacher clash.
  const p1 = period({ id: "p1", timetable_id: "tt-a", section_id: "sec-a" });
  const p2 = period({
    id: "p2",
    timetable_id: "tt-b",
    section_id: "sec-b",
    teacher_id: OTHER_TEACHER,
    room_label: "Room 8B",
  });
  const mock = new MockDb([p1, p2]);

  await assertRejects(
    () =>
      reassignTimetablePeriodTeacher(asDb(mock), ORG, SCHOOL, {
        periodId: "p1",
        teacherId: OTHER_TEACHER,
      }),
    TimetableClashError,
  );
  assertEquals(mock.updated.length, 0, "no write when the reassignment is rejected");
});

Deno.test("reassignTimetablePeriodTeacher allows reassigning to a teacher with no conflicting slot", async () => {
  // OTHER_TEACHER teaches section B at a DIFFERENT slot — no clash.
  const p1 = period({ id: "p1", timetable_id: "tt-a", section_id: "sec-a" });
  const p2 = period({
    id: "p2",
    timetable_id: "tt-b",
    section_id: "sec-b",
    teacher_id: OTHER_TEACHER,
    day_of_week: 2,
    period_number: 2,
    room_label: "Room 8B",
  });
  const mock = new MockDb([p1, p2]);

  const reassigned = await reassignTimetablePeriodTeacher(asDb(mock), ORG, SCHOOL, {
    periodId: "p1",
    teacherId: OTHER_TEACHER,
  });
  assertEquals(reassigned.teacherId, OTHER_TEACHER);
  assertEquals(mock.updated.length, 1);
});

Deno.test("reassignTimetablePeriodTeacher rejects editing a PUBLISHED timetable (belt-and-suspenders)", async () => {
  const mock = new MockDb([period({ id: "p1", status: "published" })]);
  await assertRejects(
    () =>
      reassignTimetablePeriodTeacher(asDb(mock), ORG, SCHOOL, {
        periodId: "p1",
        teacherId: OTHER_TEACHER,
      }),
    TimetablePublishedError,
  );
  assertEquals(mock.updated.length, 0);
});

Deno.test("reassignTimetablePeriodTeacher throws Period not found for an unknown period", async () => {
  const mock = new MockDb([period({ id: "p1" })]);
  await assertRejects(
    () =>
      reassignTimetablePeriodTeacher(asDb(mock), ORG, SCHOOL, {
        periodId: "missing",
        teacherId: OTHER_TEACHER,
      }),
    Error,
    "not found",
  );
});
