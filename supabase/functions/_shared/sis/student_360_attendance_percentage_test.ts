// SIS Student 360 — CANONICAL attendance-% (2026-07-09).
//
// buildStudent360Profile used to compute `attendance.percent` from ONLY the
// exact mark = 'present' count over ALL records (late/excused/half_day all
// counted against the student). It now selects the shared
// attendancePercentSql() fragment directly instead of recomputing in TS.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { buildStudent360Profile } from "./student_360_service.ts";

const ORG = "org-1";
const SCHOOL = "school-1";
const STUDENT = "a4000000-0000-4000-8000-000000000001"; // matches the UUID resolver shortcut

function mockDb(attendanceRow: Record<string, unknown> | undefined): TenantQueryClient {
  return {
    queryObject: async <T>(sql: string, _args: unknown[] = []) => {
      // resolveStudentId (UUID shortcut path).
      if (sql.includes("WHERE id = $1::uuid")) {
        return [{ id: STUDENT }] as unknown as T[];
      }
      // getStudent: core row.
      if (sql.includes("FROM students\n     WHERE id = $1 AND organization_id")) {
        return [{
          id: STUDENT,
          organization_id: ORG,
          school_id: SCHOOL,
          student_code: "SIS-STU-1",
          display_name: "Asha",
          status: "active",
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }] as unknown as T[];
      }
      // The one attendance aggregate query in buildStudent360Profile.
      if (sql.includes("FROM attendance_records")) {
        return (attendanceRow ? [attendanceRow] : []) as unknown as T[];
      }
      // Everything else (profile, enrollment, guardians, marks, homework,
      // risk, inventory, fees, conduct, documents, comms, transport):
      // no rows needed for this test's assertions.
      return [] as unknown as T[];
    },
  } as unknown as TenantQueryClient;
}

Deno.test("buildStudent360Profile: canonical % — late/half_day/excused no longer count against the student", async () => {
  // 15 present, 3 late, 2 excused, 1 half_day, 4 absent — the shared
  // cross-surface consistency fixture. Old (present-only) formula would have
  // given 15/25 = 60%; canonical gives round(18.5/23*100) = 80%.
  const db = mockDb({ present: 15, absent: 4, total: 25, percent: 80 });
  const profile = await buildStudent360Profile(db, ORG, SCHOOL, STUDENT, "admin");
  const attendance = profile.attendance as {
    present: number;
    absent: number;
    total: number;
    percent: number | null;
  };
  assertEquals(attendance.present, 15); // raw exact-mark count is unchanged
  assertEquals(attendance.absent, 4); // raw exact-mark count is unchanged
  assertEquals(attendance.total, 25);
  assertEquals(attendance.percent, 80); // CANONICAL — was 60 under the old formula
});

Deno.test("buildStudent360Profile: no attendance rows at all -> percent is null, not 0", async () => {
  const db = mockDb(undefined);
  const profile = await buildStudent360Profile(db, ORG, SCHOOL, STUDENT, "admin");
  const attendance = profile.attendance as { percent: number | null };
  assertEquals(attendance.percent, null);
});
