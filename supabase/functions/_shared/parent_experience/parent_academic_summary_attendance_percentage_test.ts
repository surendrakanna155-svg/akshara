// Parent academic summary — CANONICAL attendance-% (2026-07-09).
//
// generateParentAcademicSummary used to compute ratePercent from ONLY the
// exact mark = 'present' count over the last 30 days (late/excused/half_day
// all counted against). It now selects the shared attendancePercentSql()
// fragment directly.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildPrintableReport,
  generateParentAcademicSummary,
  parentSummaryToApi,
} from "./parent_experience_service.ts";

const ORG = "org-1";
const SCHOOL = "school-1";
const STUDENT = "student-1";

function mockDb(attendanceRow: Record<string, unknown> | undefined): TenantQueryClient {
  return {
    queryObject: async <T>(sql: string, _args: unknown[] = []) => {
      if (sql.includes("FROM attendance_records ar")) {
        return (attendanceRow ? [attendanceRow] : []) as unknown as T[];
      }
      if (sql.includes("FROM homework_submissions")) {
        return [{ submitted: "3", total: "5" }] as unknown as T[];
      }
      if (sql.includes("INSERT INTO parent_academic_summaries")) {
        // Echo back a row shaped like ParentAcademicSummaryRow, using the
        // JSONB args that were bound (mirrors ON CONFLICT ... RETURNING *).
        const [, , studentId, attendanceSummary, performanceSummary, strengths, weaknesses, homeworkStatus, examReadiness, teacherRecommendations] = _args as string[];
        return [{
          id: "row-1",
          student_id: studentId,
          attendance_summary: JSON.parse(attendanceSummary!),
          performance_summary: JSON.parse(performanceSummary!),
          strengths: JSON.parse(strengths!),
          weaknesses: JSON.parse(weaknesses!),
          homework_status: JSON.parse(homeworkStatus!),
          exam_readiness: JSON.parse(examReadiness!),
          teacher_recommendations: JSON.parse(teacherRecommendations!),
          generated_at: new Date().toISOString(),
        }] as unknown as T[];
      }
      return [] as unknown as T[];
    },
  } as unknown as TenantQueryClient;
}

Deno.test("generateParentAcademicSummary: canonical % replaces the present-only formula", async () => {
  // 15 present, 3 late, 2 excused, 1 half_day, 4 absent (the shared fixture).
  // Old formula: 15 present / 25 total = 60%. Canonical: round(18.5/23*100) = 80%.
  const db = mockDb({ present: "15", total: "25", percent: 80 });
  const row = await generateParentAcademicSummary(db, ORG, SCHOOL, STUDENT);
  const att = row.attendance_summary as { ratePercent: number | null; presentDays: number; totalDays: number };
  assertEquals(att.ratePercent, 80);
  assertEquals(att.presentDays, 15); // raw present-mark count is unchanged
  assertEquals(att.totalDays, 25); // raw total-marked count is unchanged
});

Deno.test("generateParentAcademicSummary: no attendance in the last 30 days -> ratePercent null, printable report shows '—'", async () => {
  const db = mockDb(undefined);
  const row = await generateParentAcademicSummary(db, ORG, SCHOOL, STUDENT);
  const att = row.attendance_summary as { ratePercent: number | null };
  assertEquals(att.ratePercent, null);

  const report = buildPrintableReport(parentSummaryToApi(row));
  assertEquals(report.includes("Rate: — ("), true);
  assertEquals(report.includes("null"), false);
});
