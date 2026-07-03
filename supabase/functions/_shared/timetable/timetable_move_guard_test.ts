// Roadmap gap #8 — clash-recheck + published-immutability guards on the write
// path (moveTimetablePeriod / replacePeriods via generateTimetablesForYear).
//
// In-memory mock TenantQueryClient. Proves: a move that introduces a NEW teacher
// double-booking is rejected (TimetableClashError); a legal move succeeds; a
// move on a PUBLISHED timetable is rejected app-side (TimetablePublishedError)
// even before the DB trigger would fire.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  moveTimetablePeriod,
  TimetableClashError,
  TimetablePublishedError,
} from "./timetable_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const YEAR = "ce100000-0000-4000-8000-000000000001";
const TEACHER = "b0000000-0000-4000-8000-000000000001";

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
  updated: Array<{ id: string; day: number; period: number }> = [];
  constructor(public periods: Period[]) {}

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // moveTimetablePeriod: load current period + parent timetable
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

    // UPDATE ... RETURNING (the actual move write)
    if (sql.includes("UPDATE academic_timetable_periods") && sql.includes("SET day_of_week = $4")) {
      const [id, _org, _school, day, period, room] = args as [
        string,
        string,
        string,
        number,
        number,
        string | null,
      ];
      const p = this.periods.find((x) => x.id === id)!;
      p.day_of_week = day;
      p.period_number = period;
      if (room !== null) p.room_label = room;
      this.updated.push({ id, day, period });
      return [{
        id: p.id,
        timetable_id: p.timetable_id,
        day_of_week: p.day_of_week,
        period_number: p.period_number,
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

Deno.test("moveTimetablePeriod succeeds for a clash-free move", async () => {
  const mock = new MockDb([period({ id: "p1" })]);
  const moved = await moveTimetablePeriod(asDb(mock), ORG, SCHOOL, {
    periodId: "p1",
    targetDayOfWeek: 2,
    targetPeriodNumber: 3,
  });
  assertEquals(moved.dayOfWeek, 2);
  assertEquals(moved.periodNumber, 3);
  assertEquals(mock.updated.length, 1);
});

Deno.test("moveTimetablePeriod rejects a move that double-books a teacher (TIMETABLE_CLASH)", async () => {
  // Same teacher already teaches section B at day 2 / period 3. Moving p1 there
  // creates a NEW teacher clash.
  const p1 = period({ id: "p1", timetable_id: "tt-a", section_id: "sec-a" });
  const p2 = period({
    id: "p2",
    timetable_id: "tt-b",
    section_id: "sec-b",
    day_of_week: 2,
    period_number: 3,
    room_label: "Room 8B",
  });
  const mock = new MockDb([p1, p2]);

  await assertRejects(
    () =>
      moveTimetablePeriod(asDb(mock), ORG, SCHOOL, {
        periodId: "p1",
        targetDayOfWeek: 2,
        targetPeriodNumber: 3,
      }),
    TimetableClashError,
  );
  assertEquals(mock.updated.length, 0, "no write when the move is rejected");
});

Deno.test("moveTimetablePeriod rejects a move that double-books a room (TIMETABLE_CLASH)", async () => {
  // Different teachers, but moving into a slot where the same room is already used.
  const p1 = period({ id: "p1", timetable_id: "tt-a", section_id: "sec-a", room_label: "Lab 1" });
  const p2 = period({
    id: "p2",
    timetable_id: "tt-b",
    section_id: "sec-b",
    teacher_id: "b0000000-0000-4000-8000-000000000002",
    day_of_week: 2,
    period_number: 3,
    room_label: "Lab 1",
  });
  const mock = new MockDb([p1, p2]);

  await assertRejects(
    () =>
      moveTimetablePeriod(asDb(mock), ORG, SCHOOL, {
        periodId: "p1",
        targetDayOfWeek: 2,
        targetPeriodNumber: 3,
      }),
    TimetableClashError,
  );
  assertEquals(mock.updated.length, 0);
});

Deno.test("moveTimetablePeriod rejects editing a PUBLISHED timetable (belt-and-suspenders)", async () => {
  const mock = new MockDb([period({ id: "p1", status: "published" })]);
  await assertRejects(
    () =>
      moveTimetablePeriod(asDb(mock), ORG, SCHOOL, {
        periodId: "p1",
        targetDayOfWeek: 2,
        targetPeriodNumber: 3,
      }),
    TimetablePublishedError,
  );
  assertEquals(mock.updated.length, 0);
});

Deno.test("moveTimetablePeriod throws Period not found for an unknown period", async () => {
  const mock = new MockDb([period({ id: "p1" })]);
  await assertRejects(
    () =>
      moveTimetablePeriod(asDb(mock), ORG, SCHOOL, {
        periodId: "missing",
        targetDayOfWeek: 2,
        targetPeriodNumber: 3,
      }),
    Error,
    "not found",
  );
});
