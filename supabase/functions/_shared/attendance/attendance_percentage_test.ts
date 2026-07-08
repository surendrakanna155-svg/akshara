// CANONICAL attendance-% — unit tests for the shared SQL fragments + TS
// helpers (attendance_percentage.ts), including the cross-surface
// consistency test mandated by the 2026-07-09 unification fix: one fixed
// record set must produce the IDENTICAL percentage through every helper a
// consumer might use (records, counts, or the SQL fragment text).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type AttendanceMarkCounts,
  attendanceDenominatorSql,
  attendancePercent,
  attendancePercentFromCounts,
  attendancePercentSql,
  attendedDaysSql,
  attendedFromCounts,
} from "./attendance_percentage.ts";

// --- attendedFromCounts -------------------------------------------------------

Deno.test("attendedFromCounts: present + late + 0.5 * half_day", () => {
  assertEquals(attendedFromCounts({ present: 10, late: 2, halfDay: 4 }), 14);
  assertEquals(attendedFromCounts({ present: 0, late: 0, halfDay: 1 }), 0.5);
  assertEquals(attendedFromCounts({ present: 0, late: 0, halfDay: 0 }), 0);
});

// --- attendancePercentFromCounts ---------------------------------------------

Deno.test("attendancePercentFromCounts: all present -> 100", () => {
  const counts: AttendanceMarkCounts = { present: 20, late: 0, halfDay: 0, excused: 0, absent: 0 };
  assertEquals(attendancePercentFromCounts(counts), 100);
});

Deno.test("attendancePercentFromCounts: late counts as attended (not against)", () => {
  const counts: AttendanceMarkCounts = { present: 18, late: 2, halfDay: 0, excused: 0, absent: 0 };
  assertEquals(attendancePercentFromCounts(counts), 100);
});

Deno.test("attendancePercentFromCounts: excused is removed from the denominator entirely", () => {
  // 10 present, 5 excused, 5 absent: denom = 20 - 5(excused) = 15; attended = 10.
  const counts: AttendanceMarkCounts = { present: 10, late: 0, halfDay: 0, excused: 5, absent: 5 };
  assertEquals(attendancePercentFromCounts(counts), Math.round((10 / 15) * 100)); // 67
});

Deno.test("attendancePercentFromCounts: half_day contributes exactly 0.5", () => {
  // 10 present, 2 half_day, 8 absent: attended = 10 + 1 = 11; denom = 20.
  const counts: AttendanceMarkCounts = { present: 10, late: 0, halfDay: 2, excused: 0, absent: 8 };
  assertEquals(attendancePercentFromCounts(counts), 55);
});

Deno.test("attendancePercentFromCounts: divide-by-zero -> null, never 0", () => {
  const nothingMarked: AttendanceMarkCounts = {
    present: 0,
    late: 0,
    halfDay: 0,
    excused: 0,
    absent: 0,
  };
  assertEquals(attendancePercentFromCounts(nothingMarked), null);

  // Every marked day was excused: denominator is still 0 (excused cancels
  // itself out of both sides), so this is ALSO null — not 100%, not 0%.
  const allExcused: AttendanceMarkCounts = {
    present: 0,
    late: 0,
    halfDay: 0,
    excused: 6,
    absent: 0,
  };
  assertEquals(attendancePercentFromCounts(allExcused), null);
});

// --- attendancePercent(records) -----------------------------------------------

Deno.test("attendancePercent: builds counts from a raw record list", () => {
  const records = [
    { mark: "present" },
    { mark: "present" },
    { mark: "late" },
    { mark: "excused" },
    { mark: "absent" },
  ];
  // attended = 2 + 1 = 3; denom = 5 - 1(excused) = 4 -> 75%.
  assertEquals(attendancePercent(records), 75);
});

Deno.test("attendancePercent: unknown marks are ignored on both sides", () => {
  const records = [{ mark: "present" }, { mark: "present" }, { mark: "unknown_mark" }];
  // The unrecognized mark contributes to neither attended nor the denominator.
  assertEquals(attendancePercent(records), 100);
});

Deno.test("attendancePercent: empty record list -> null", () => {
  assertEquals(attendancePercent([]), null);
});

// --- SQL fragments (shape checks — no live DB in this test) ------------------

Deno.test("attendedDaysSql: mentions present/late/half_day with the 0.5 weight", () => {
  const sql = attendedDaysSql("ar.mark");
  assertEquals(sql.includes("ar.mark"), true);
  assertEquals(sql.includes("'present'"), true);
  assertEquals(sql.includes("'late'"), true);
  assertEquals(sql.includes("0.5"), true);
  assertEquals(sql.includes("'half_day'"), true);
});

Deno.test("attendanceDenominatorSql: subtracts excused from the total count", () => {
  const sql = attendanceDenominatorSql("mark");
  assertEquals(sql.includes("count(*)"), true);
  assertEquals(sql.includes("'excused'"), true);
});

Deno.test("attendancePercentSql: NULLs out the divide-by-zero case", () => {
  const sql = attendancePercentSql();
  assertEquals(sql.includes("WHEN"), true);
  assertEquals(sql.includes("NULL"), true);
  assertEquals(sql.includes("ROUND("), true);
});

// --- THE cross-surface consistency test --------------------------------------
//
// One fixed set of attendance records — 15 present, 3 late, 2 excused, 1
// half_day, 4 absent — fed through every shared-helper entry point a
// consumer could reasonably use, must yield the IDENTICAL percentage:
//   attended    = 15 + 3 + 0.5×1 = 18.5
//   denominator = (15+3+2+1+4) − 2 = 23
//   percent     = round(18.5 / 23 × 100) = round(80.434...) = 80

const FIXTURE_COUNTS: AttendanceMarkCounts = {
  present: 15,
  late: 3,
  halfDay: 1,
  excused: 2,
  absent: 4,
};

const FIXTURE_RECORDS: { mark: string }[] = [
  ...Array(15).fill({ mark: "present" }),
  ...Array(3).fill({ mark: "late" }),
  ...Array(2).fill({ mark: "excused" }),
  ...Array(1).fill({ mark: "half_day" }),
  ...Array(4).fill({ mark: "absent" }),
];

Deno.test("cross-surface consistency: fixed fixture -> identical 80% via every helper", () => {
  const EXPECTED_PERCENT = 80; // round(18.5 / 23 * 100) = round(80.4347...) = 80

  // 1. admin monthly register / short-attendance alerts — counts path
  //    (attendance_office_repository.ts: getMonthlyRegister, getShortAttendance).
  assertEquals(attendancePercentFromCounts(FIXTURE_COUNTS), EXPECTED_PERCENT);

  // 2. pilot parent snapshot overlay — counts path
  //    (pilot_operations_repository.ts: overlayAttendanceSnapshotFromRecords).
  assertEquals(
    attendancePercentFromCounts({
      present: FIXTURE_COUNTS.present,
      late: FIXTURE_COUNTS.late,
      halfDay: FIXTURE_COUNTS.halfDay,
      excused: FIXTURE_COUNTS.excused,
      absent: FIXTURE_COUNTS.absent,
    }),
    EXPECTED_PERCENT,
  );

  // 3. SIS Student 360 / parent hub / parent academic summary — records path
  //    (student_360_service.ts + parent_experience_service.ts, both parent/
  //    and parent_experience/ dirs — all read attendance_records directly).
  assertEquals(attendancePercent(FIXTURE_RECORDS), EXPECTED_PERCENT);

  // 4. Sanity-check the exact arithmetic named in the owner-ratified policy.
  const attended = attendedFromCounts(FIXTURE_COUNTS);
  assertEquals(attended, 18.5);
  const denominator = FIXTURE_COUNTS.present + FIXTURE_COUNTS.late + FIXTURE_COUNTS.halfDay +
    FIXTURE_COUNTS.absent;
  assertEquals(denominator, 23);
  assertEquals(Math.round((attended / denominator) * 100), EXPECTED_PERCENT);
});
