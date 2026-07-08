// Admin monthly register + short-attendance alerts — CANONICAL
// attendance-% (2026-07-09). getMonthlyRegister used to count only
// present+late as "attended" and drop half_day/excused entirely; it now
// routes through the shared attendance_percentage.ts helpers.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  attendanceDenominatorSql,
  attendancePercentSql,
  attendedDaysSql,
} from "./attendance_percentage.ts";
import { getMonthlyRegister, getShortAttendance } from "./attendance_office_repository.ts";

const ORG = "org-1";
const SCHOOL = "school-1";
const CLASS = "8-A";

interface Capture {
  sql: string;
  args: unknown[];
}

function mockDb(
  routes: Array<{ match: string; rows: unknown[] }>,
  captures: Capture[] = [],
): TenantQueryClient {
  return {
    queryObject: async <T>(sql: string, args: unknown[] = []) => {
      captures.push({ sql, args });
      const hit = routes.find((r) => sql.includes(r.match));
      return (hit?.rows ?? []) as T[];
    },
  } as unknown as TenantQueryClient;
}

// --- getMonthlyRegister (TS aggregation) -------------------------------------

Deno.test("getMonthlyRegister: half_day now maps to its own calendar code (H), not '-'", async () => {
  const rows = [
    {
      student_id: "s1",
      student_name: "Asha",
      roll_number: "1",
      class_label: CLASS,
      day_of_month: 1,
      mark: "half_day",
    },
  ];
  const db = mockDb([{ match: "FROM attendance_records ar", rows }]);
  const register = await getMonthlyRegister(db, ORG, SCHOOL, CLASS, "2026-07");
  assertEquals(register.students[0]!.marks[1], "H");
});

Deno.test("getMonthlyRegister: canonical % across a mixed month (matches the shared consistency fixture)", async () => {
  // 15 present, 3 late, 2 excused, 1 half_day, 4 absent for one student.
  const marks = [
    ...Array(15).fill("present"),
    ...Array(3).fill("late"),
    ...Array(2).fill("excused"),
    ...Array(1).fill("half_day"),
    ...Array(4).fill("absent"),
  ];
  const rows = marks.map((mark, i) => ({
    student_id: "s1",
    student_name: "Asha",
    roll_number: "1",
    class_label: CLASS,
    day_of_month: i + 1,
    mark,
  }));
  const db = mockDb([{ match: "FROM attendance_records ar", rows }]);
  const register = await getMonthlyRegister(db, ORG, SCHOOL, CLASS, "2026-07");
  const student = register.students[0]!;
  assertEquals(student.marked_days, 25);
  assertEquals(student.present_days, 18.5); // attended = 15 + 3 + 0.5*1
  assertEquals(student.percent_present, 80); // round(18.5 / 23 * 100)
});

Deno.test("getMonthlyRegister: no records for the month -> null percent, not 0", async () => {
  const db = mockDb([{ match: "FROM attendance_records ar", rows: [] }]);
  const register = await getMonthlyRegister(db, ORG, SCHOOL, CLASS, "2026-07");
  assertEquals(register.students, []);
});

Deno.test("getMonthlyRegister: a student whose whole month is excused -> null percent, not 0", async () => {
  const rows = [1, 2, 3].map((d) => ({
    student_id: "s1",
    student_name: "Asha",
    roll_number: "1",
    class_label: CLASS,
    day_of_month: d,
    mark: "excused",
  }));
  const db = mockDb([{ match: "FROM attendance_records ar", rows }]);
  const register = await getMonthlyRegister(db, ORG, SCHOOL, CLASS, "2026-07");
  const student = register.students[0]!;
  assertEquals(student.marked_days, 3);
  assertEquals(student.present_days, 0);
  assertEquals(student.percent_present, null);
});

// --- getShortAttendance (SQL fragment wiring) --------------------------------

Deno.test("getShortAttendance: SELECT embeds the shared canonical SQL fragments verbatim", async () => {
  const captures: Capture[] = [];
  const db = mockDb(
    [{ match: "WITH school_days AS", rows: [] }],
    captures,
  );
  await getShortAttendance(db, ORG, SCHOOL, 75, 30);
  const sql = captures[0]!.sql;
  assertEquals(sql.includes(attendedDaysSql("ar.mark")), true);
  assertEquals(sql.includes(attendanceDenominatorSql("ar.mark")), true);
  assertEquals(sql.includes(attendancePercentSql("ar.mark")), true);
  // The WHERE/ORDER BY reference the CTE's own precomputed column, never a
  // second inline recomputation that could drift from the SELECT list.
  assertEquals(sql.includes("ss.percent_present < $3"), true);
});
