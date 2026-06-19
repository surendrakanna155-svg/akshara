import type { TenantQueryClient } from "../tenant_db.ts";

export interface ParentAcademicSummaryRow {
  id: string;
  student_id: string;
  attendance_summary: Record<string, unknown>;
  performance_summary: Record<string, unknown>;
  strengths: unknown;
  weaknesses: unknown;
  homework_status: Record<string, unknown>;
  exam_readiness: Record<string, unknown>;
  teacher_recommendations: unknown;
  generated_at: string;
}

export async function generateParentAcademicSummary(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
): Promise<ParentAcademicSummaryRow> {
  const attendance = await db.queryObject<{ present: string; total: string }>(
    `SELECT count(*) FILTER (WHERE mark = 'present')::text AS present,
            count(*)::text AS total
     FROM attendance_records ar
     JOIN attendance_sessions s ON s.id = ar.session_id
     WHERE ar.organization_id = $1 AND ar.school_id = $2 AND ar.student_id = $3::uuid
       AND s.session_date > current_date - interval '30 days'`,
    [orgId, schoolId, studentId],
  );

  const homework = await db.queryObject<{ submitted: string; total: string }>(
    `SELECT count(*) FILTER (WHERE status = 'submitted')::text AS submitted,
            count(*)::text AS total
     FROM homework_submissions
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3::uuid`,
    [orgId, schoolId, studentId],
  );

  const present = Number(attendance[0]?.present ?? 0);
  const totalAtt = Number(attendance[0]?.total ?? 0);
  const attRate = totalAtt > 0 ? Math.round((present / totalAtt) * 100) : 100;

  const hwSubmitted = Number(homework[0]?.submitted ?? 0);
  const hwTotal = Number(homework[0]?.total ?? 1);

  const summary = {
    attendance_summary: {
      ratePercent: attRate,
      presentDays: present,
      totalDays: totalAtt,
      alert: attRate < 75 ? "Attendance below 75% — please review" : null,
    },
    performance_summary: {
      overallGrade: attRate >= 90 ? "A" : attRate >= 75 ? "B" : "C",
      trend: attRate >= 85 ? "improving" : "needs_attention",
    },
    strengths: attRate >= 85 ? ["Regular attendance", "Consistent homework submission"] : ["Participation in class"],
    weaknesses: attRate < 75 ? ["Attendance gaps"] : hwSubmitted < hwTotal ? ["Pending homework"] : [],
    homework_status: {
      submitted: hwSubmitted,
      pending: Math.max(0, hwTotal - hwSubmitted),
      completionRate: Math.round((hwSubmitted / hwTotal) * 100),
    },
    exam_readiness: {
      readinessScore: Math.min(100, Math.round((attRate + (hwSubmitted / hwTotal) * 100) / 2)),
      recommendation: attRate >= 80 ? "On track for upcoming exams" : "Focus on attendance before exams",
    },
    teacher_recommendations: [
      "Review homework daily with your child",
      attRate < 80 ? "Ensure regular school attendance" : "Maintain current study routine",
    ],
  };

  const rows = await db.queryObject<ParentAcademicSummaryRow>(
    `INSERT INTO parent_academic_summaries (
       organization_id, school_id, student_id,
       attendance_summary, performance_summary, strengths, weaknesses,
       homework_status, exam_readiness, teacher_recommendations, generated_at
     ) VALUES ($1, $2, $3::uuid, $4::jsonb, $5::jsonb, $6::jsonb, $7::jsonb, $8::jsonb, $9::jsonb, $10::jsonb, now())
     ON CONFLICT (organization_id, school_id, student_id)
     DO UPDATE SET
       attendance_summary = EXCLUDED.attendance_summary,
       performance_summary = EXCLUDED.performance_summary,
       strengths = EXCLUDED.strengths,
       weaknesses = EXCLUDED.weaknesses,
       homework_status = EXCLUDED.homework_status,
       exam_readiness = EXCLUDED.exam_readiness,
       teacher_recommendations = EXCLUDED.teacher_recommendations,
       generated_at = now()
     RETURNING *`,
    [
      orgId,
      schoolId,
      studentId,
      JSON.stringify(summary.attendance_summary),
      JSON.stringify(summary.performance_summary),
      JSON.stringify(summary.strengths),
      JSON.stringify(summary.weaknesses),
      JSON.stringify(summary.homework_status),
      JSON.stringify(summary.exam_readiness),
      JSON.stringify(summary.teacher_recommendations),
    ],
  );
  return rows[0]!;
}

export async function getParentAcademicSummary(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
): Promise<ParentAcademicSummaryRow | null> {
  const rows = await db.queryObject<ParentAcademicSummaryRow>(
    `SELECT * FROM parent_academic_summaries
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3::uuid`,
    [orgId, schoolId, studentId],
  );
  return rows[0] ?? null;
}

export async function getParentActivationStats(
  db: TenantQueryClient,
  schoolId: string,
): Promise<{
  total: number;
  active: number;
  pending: number;
  activationRate: number;
  adoptionRate: number;
  dailyActiveParents: number;
  monthlyActiveParents: number;
}> {
  const rows = await db.queryObject<{ total: string; active: string }>(
    `SELECT count(*)::text AS total,
            count(*) FILTER (WHERE status = 'active')::text AS active
     FROM school_memberships WHERE school_id = $1 AND role = 'parent'`,
    [schoolId],
  );
  const total = Number(rows[0]?.total ?? 0);
  const active = Number(rows[0]?.active ?? 0);
  const pending = Math.max(0, total - active);

  const engagement = await db.queryObject<{
    daily: string;
    monthly: string;
    adoption: string;
  }>(
    `SELECT count(*) FILTER (WHERE app_sessions_30d > 0 AND last_active_at > now() - interval '1 day')::text AS daily,
            count(*) FILTER (WHERE app_sessions_30d > 0)::text AS monthly,
            count(*) FILTER (WHERE engagement_score >= 50)::text AS adoption
     FROM parent_engagement_snapshots
     WHERE school_id = $1`,
    [schoolId],
  ).catch(() => [{ daily: "0", monthly: "0", adoption: "0" }]);

  const dailyActive = Number(engagement[0]?.daily ?? 0);
  const monthlyActive = Number(engagement[0]?.monthly ?? active);
  const adoptionCount = Number(engagement[0]?.adoption ?? 0);

  return {
    total,
    active,
    pending,
    activationRate: total > 0 ? Math.round((active / total) * 100) : 0,
    adoptionRate: total > 0 ? Math.round((adoptionCount / total) * 100) : 0,
    dailyActiveParents: dailyActive,
    monthlyActiveParents: monthlyActive,
  };
}

export function parentSummaryToApi(row: ParentAcademicSummaryRow) {
  return {
    studentId: row.student_id,
    attendanceSummary: row.attendance_summary,
    performanceSummary: row.performance_summary,
    strengths: row.strengths,
    weaknesses: row.weaknesses,
    homeworkStatus: row.homework_status,
    examReadiness: row.exam_readiness,
    teacherRecommendations: row.teacher_recommendations,
    generatedAt: row.generated_at,
  };
}

export function buildPrintableReport(summary: ReturnType<typeof parentSummaryToApi>): string {
  const att = summary.attendanceSummary as Record<string, unknown>;
  const perf = summary.performanceSummary as Record<string, unknown>;
  return [
    "AKSHARA SCHOOL — PARENT ACADEMIC REPORT",
    "========================================",
    `Generated: ${summary.generatedAt}`,
    "",
    "ATTENDANCE",
    `Rate: ${att.ratePercent}% (${att.presentDays}/${att.totalDays} days)`,
    att.alert ? `Alert: ${att.alert}` : "",
    "",
    "PERFORMANCE",
    `Overall: ${perf.overallGrade} · Trend: ${perf.trend}`,
    "",
    "STRENGTHS",
    ...(summary.strengths as string[]).map((s) => `• ${s}`),
    "",
    "AREAS TO IMPROVE",
    ...(summary.weaknesses as string[]).map((w) => `• ${w}`),
    "",
    "TEACHER RECOMMENDATIONS",
    ...(summary.teacherRecommendations as string[]).map((r) => `• ${r}`),
  ].filter(Boolean).join("\n");
}
