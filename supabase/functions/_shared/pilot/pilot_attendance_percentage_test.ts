// Pilot parent snapshot overlay — CANONICAL attendance-% (2026-07-09).
//
// Covers overlayAttendanceSnapshotFromRecords (pilot_operations_repository.ts),
// which used to count excused/half_day as full presence and drop late
// entirely. It now routes through the shared attendance_percentage.ts helper
// like every other surface.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { overlayAttendanceSnapshotFromRecords } from "./pilot_operations_repository.ts";

const ORG = "org-1";
const SCHOOL = "school-1";
const STUDENT = "student-1";

function mockDb(rows: { mark: string; session_date: string }[]): TenantQueryClient {
  return {
    queryObject: async <T>(sql: string, _args: unknown[] = []) => {
      if (sql.includes("FROM attendance_records ar")) return rows as unknown as T[];
      return [] as T[];
    },
  } as unknown as TenantQueryClient;
}

function rows(marks: string[]): { mark: string; session_date: string }[] {
  return marks.map((mark, i) => ({
    mark,
    session_date: `2026-07-${String(i + 1).padStart(2, "0")}`,
  }));
}

Deno.test("overlayAttendanceSnapshotFromRecords: late counts as attended, not against", async () => {
  const db = mockDb(rows(["present", "present", "late", "late"]));
  const merged = await overlayAttendanceSnapshotFromRecords(db, ORG, SCHOOL, STUDENT, {});
  const kpi = merged.kpi as { attendancePercent: number | null; absentDays: number; lateDays: number };
  // attended = 2 + 2 = 4; denom = 4 -> 100%.
  assertEquals(kpi.attendancePercent, 100);
  assertEquals(kpi.lateDays, 2);
  assertEquals(kpi.absentDays, 0);
});

Deno.test("overlayAttendanceSnapshotFromRecords: excused is removed from the denominator, half_day is 0.5", async () => {
  const db = mockDb(rows(["present", "present", "excused", "half_day", "absent"]));
  const merged = await overlayAttendanceSnapshotFromRecords(db, ORG, SCHOOL, STUDENT, {});
  const kpi = merged.kpi as { attendancePercent: number | null };
  // attended = 2 + 0.5 = 2.5; denom = (2+0+1+0+1) - 1(excused) ... using the
  // canonical denom = present+late+halfDay+absent = 2+0+1+1 = 4 -> 62.5% -> 63.
  assertEquals(kpi.attendancePercent, 63);
});

Deno.test("overlayAttendanceSnapshotFromRecords: all-excused -> null, not 0 and not 100", async () => {
  const db = mockDb(rows(["excused", "excused"]));
  const merged = await overlayAttendanceSnapshotFromRecords(db, ORG, SCHOOL, STUDENT, {});
  const kpi = merged.kpi as { attendancePercent: number | null };
  assertEquals(kpi.attendancePercent, null);
});

Deno.test("overlayAttendanceSnapshotFromRecords: no records at all -> snapshot passthrough, no kpi crash", async () => {
  const db = mockDb([]);
  const merged = await overlayAttendanceSnapshotFromRecords(db, ORG, SCHOOL, STUDENT, {
    childName: "Asha",
  });
  assertEquals(merged.childName, "Asha");
  assertEquals("kpi" in merged, false); // matches pre-existing early-return behaviour for 0 rows
});
