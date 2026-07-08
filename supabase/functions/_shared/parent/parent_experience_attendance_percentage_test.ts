// Parent experience hub — CANONICAL attendance-% (2026-07-09).
//
// buildParentExperienceHub used to independently recompute `attendance.pct`
// from the raw present/total counts it read off the Student 360 profile
// (its OWN present-only formula, same bug family as student_360_service.ts).
// It now trusts the canonical `percent` the profile already computed —
// never recomputing locally.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { buildParentExperienceHub } from "./parent_experience_service.ts";

const ORG = "org-1";
const SCHOOL = "school-1";
const STUDENT = "a4000000-0000-4000-8000-000000000001"; // matches the UUID resolver shortcut

function mockDb(attendanceRow: Record<string, unknown> | undefined): TenantQueryClient {
  return {
    queryObject: async <T>(sql: string, _args: unknown[] = []) => {
      if (sql.includes("WHERE id = $1::uuid")) {
        return [{ id: STUDENT }] as unknown as T[];
      }
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
      if (sql.includes("FROM attendance_records")) {
        return (attendanceRow ? [attendanceRow] : []) as unknown as T[];
      }
      return [] as unknown as T[];
    },
  } as unknown as TenantQueryClient;
}

Deno.test("buildParentExperienceHub: attendance.pct trusts the canonical Student 360 percent (no local recompute)", async () => {
  // 15 present, 3 late, 2 excused, 1 half_day, 4 absent — the shared fixture.
  // The OLD local recompute (present/total) would have given 15/25 = 60%;
  // trusting the canonical profile percent gives 80%.
  const db = mockDb({ present: 15, absent: 4, total: 25, percent: 80 });
  const hub = await buildParentExperienceHub(db, ORG, SCHOOL, STUDENT);
  assertEquals(hub.attendance.present, 15);
  assertEquals(hub.attendance.absent, 4);
  assertEquals(hub.attendance.total, 25);
  assertEquals(hub.attendance.pct, 80);
});

Deno.test("buildParentExperienceHub: no attendance data -> pct is null, not 0", async () => {
  const db = mockDb(undefined);
  const hub = await buildParentExperienceHub(db, ORG, SCHOOL, STUDENT);
  assertEquals(hub.attendance.pct, null);
});
