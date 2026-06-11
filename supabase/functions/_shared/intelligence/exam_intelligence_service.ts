import type { TenantQueryClient } from "../tenant_db.ts";

export interface ExamIntelligenceFilters {
  className?: string;
  subjectName?: string;
  examType?: string;
}

export interface ExamAnalytics {
  totalExams: number;
  studentsAssessed: number;
  averageScorePercent: number;
  passRatePercent: number;
  topPerformers: Array<{ studentId: string; studentName: string; avgPercent: number }>;
  classBreakdown: Array<{ className: string; avgPercent: number; studentCount: number }>;
  insights: string[];
}

export interface SubjectPerformanceItem {
  subjectName: string;
  avgPercent: number;
  studentCount: number;
  passRate: number;
  trend: "improving" | "stable" | "declining";
}

export interface WeakChapterItem {
  chapter: string;
  subjectName: string;
  avgPercent: number;
  studentCount: number;
  recommendation: string;
}

export interface ResultIntelligence {
  passCount: number;
  failCount: number;
  distinctionCount: number;
  gradeDistribution: Array<{ grade: string; count: number }>;
  classRankings: Array<{ className: string; avgPercent: number; rank: number }>;
  insights: string[];
}

export interface AcademicForecast {
  forecastPeriod: string;
  predictedAvgPercent: number;
  atRiskStudentCount: number;
  improvingStudentCount: number;
  subjectForecasts: Array<{ subjectName: string; predictedAvg: number; confidence: string }>;
  recommendations: string[];
}

export interface RankMovementItem {
  studentId: string;
  studentName: string;
  className: string;
  previousRank: number;
  currentRank: number;
  movement: number;
  direction: "up" | "down" | "stable";
}

function clamp(n: number): number {
  return Math.max(0, Math.min(100, Math.round(n)));
}

export async function buildExamAnalytics(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: ExamIntelligenceFilters = {},
): Promise<ExamAnalytics> {
  const params: unknown[] = [organizationId, schoolId];
  let classFilter = "";
  if (filters.className) {
    params.push(`%${filters.className}%`);
    classFilter = ` AND em.class_label ILIKE $${params.length}`;
  }

  const examRows = await client.queryObject<{
    exam_count: number;
    student_count: number;
    avg_pct: number;
    pass_count: number;
    total_marks: number;
  }>(
    `SELECT
       count(DISTINCT em.exam_id)::int AS exam_count,
       count(DISTINCT em.student_id)::int AS student_count,
       coalesce(avg(
         CASE WHEN em.max_marks > 0
           THEN (em.marks_obtained::float / em.max_marks) * 100 ELSE 0 END
       ), 0)::int AS avg_pct,
       count(*) FILTER (
         WHERE em.max_marks > 0 AND (em.marks_obtained::float / em.max_marks) >= 0.4
       )::int AS pass_count,
       count(*)::int AS total_marks
     FROM exam_mark_entries em
     WHERE em.organization_id = $1 AND em.school_id = $2${classFilter}`,
    params,
  );

  const summary = examRows[0] ?? {
    exam_count: 0,
    student_count: 0,
    avg_pct: 0,
    pass_count: 0,
    total_marks: 0,
  };

  const topRows = await client.queryObject<{
    student_id: string;
    student_name: string;
    avg_pct: number;
  }>(
    `SELECT
       em.student_id,
       s.display_name AS student_name,
       coalesce(avg(
         CASE WHEN em.max_marks > 0
           THEN (em.marks_obtained::float / em.max_marks) * 100 ELSE 0 END
       ), 0)::int AS avg_pct
     FROM exam_mark_entries em
     JOIN students s ON s.id = em.student_id
     WHERE em.organization_id = $1 AND em.school_id = $2${classFilter}
     GROUP BY em.student_id, s.display_name
     ORDER BY avg_pct DESC
     LIMIT 5`,
    params,
  );

  const classRows = await client.queryObject<{
    class_name: string;
    avg_pct: number;
    student_count: number;
  }>(
    `SELECT
       em.class_label AS class_name,
       coalesce(avg(
         CASE WHEN em.max_marks > 0
           THEN (em.marks_obtained::float / em.max_marks) * 100 ELSE 0 END
       ), 0)::int AS avg_pct,
       count(DISTINCT em.student_id)::int AS student_count
     FROM exam_mark_entries em
     WHERE em.organization_id = $1 AND em.school_id = $2${classFilter}
       AND em.class_label <> ''
     GROUP BY em.class_label
     ORDER BY avg_pct DESC`,
    params,
  );

  const passRate = summary.total_marks > 0
    ? clamp((summary.pass_count / summary.total_marks) * 100)
    : 0;

  const insights: string[] = [];
  if (summary.exam_count === 0) {
    insights.push("No exam mark entries found — import exam results to enable analytics.");
  } else {
    insights.push(`${summary.exam_count} exams assessed across ${summary.student_count} students.`);
    insights.push(`School average: ${summary.avg_pct}% with ${passRate}% pass rate.`);
    if (summary.avg_pct < 60) insights.push("Overall performance below target — review weak chapters.");
    if (passRate >= 85) insights.push("Strong pass rate — maintain current teaching strategies.");
  }

  return {
    totalExams: summary.exam_count,
    studentsAssessed: summary.student_count,
    averageScorePercent: summary.avg_pct,
    passRatePercent: passRate,
    topPerformers: topRows.map((r) => ({
      studentId: r.student_id,
      studentName: r.student_name,
      avgPercent: r.avg_pct,
    })),
    classBreakdown: classRows.map((r) => ({
      className: r.class_name,
      avgPercent: r.avg_pct,
      studentCount: r.student_count,
    })),
    insights,
  };
}

export async function buildSubjectPerformance(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: ExamIntelligenceFilters = {},
): Promise<SubjectPerformanceItem[]> {
  const params: unknown[] = [organizationId, schoolId];
  let classFilter = "";
  if (filters.className) {
    params.push(`%${filters.className}%`);
    classFilter = ` AND em.class_label ILIKE $${params.length}`;
  }

  const rows = await client.queryObject<{
    subject_name: string;
    avg_pct: number;
    student_count: number;
    pass_count: number;
    total_count: number;
  }>(
    `SELECT
       coalesce(em.exam_title, 'General') AS subject_name,
       coalesce(avg(
         CASE WHEN em.max_marks > 0
           THEN (em.marks_obtained::float / em.max_marks) * 100 ELSE 0 END
       ), 0)::int AS avg_pct,
       count(DISTINCT em.student_id)::int AS student_count,
       count(*) FILTER (
         WHERE em.max_marks > 0 AND (em.marks_obtained::float / em.max_marks) >= 0.4
       )::int AS pass_count,
       count(*)::int AS total_count
     FROM exam_mark_entries em
     WHERE em.organization_id = $1 AND em.school_id = $2${classFilter}
     GROUP BY em.exam_title
     ORDER BY avg_pct ASC`,
    params,
  );

  return rows.map((r) => ({
    subjectName: r.subject_name,
    avgPercent: r.avg_pct,
    studentCount: r.student_count,
    passRate: r.total_count > 0 ? clamp((r.pass_count / r.total_count) * 100) : 0,
    trend: r.avg_pct >= 70 ? "improving" : r.avg_pct >= 50 ? "stable" : "declining",
  }));
}

export async function detectWeakChapters(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: ExamIntelligenceFilters = {},
): Promise<WeakChapterItem[]> {
  const params: unknown[] = [organizationId, schoolId];
  let classFilter = "";
  let subjectFilter = "";
  if (filters.className) {
    params.push(`%${filters.className}%`);
    classFilter = ` AND em.class_label ILIKE $${params.length}`;
  }
  if (filters.subjectName) {
    params.push(`%${filters.subjectName}%`);
    subjectFilter = ` AND em.exam_title ILIKE $${params.length}`;
  }

  const rows = await client.queryObject<{
    chapter: string;
    subject_name: string;
    avg_pct: number;
    student_count: number;
  }>(
    `SELECT
       coalesce(em.class_label, 'General') AS chapter,
       coalesce(em.exam_title, 'General') AS subject_name,
       coalesce(avg(
         CASE WHEN em.max_marks > 0
           THEN (em.marks_obtained::float / em.max_marks) * 100 ELSE 0 END
       ), 0)::int AS avg_pct,
       count(DISTINCT em.student_id)::int AS student_count
     FROM exam_mark_entries em
     WHERE em.organization_id = $1 AND em.school_id = $2${classFilter}${subjectFilter}
     GROUP BY em.class_label, em.exam_title
     HAVING avg(
       CASE WHEN em.max_marks > 0
         THEN (em.marks_obtained::float / em.max_marks) * 100 ELSE 70 END
     ) < 65
     ORDER BY avg_pct ASC
     LIMIT 12`,
    params,
  );

  return rows.map((r) => ({
    chapter: r.chapter,
    subjectName: r.subject_name,
    avgPercent: r.avg_pct,
    studentCount: r.student_count,
    recommendation: r.avg_pct < 45
      ? "Priority remedial — schedule revision classes"
      : "Revision worksheets and targeted homework recommended",
  }));
}

export async function buildResultIntelligence(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: ExamIntelligenceFilters = {},
): Promise<ResultIntelligence> {
  const params: unknown[] = [organizationId, schoolId];
  let classFilter = "";
  if (filters.className) {
    params.push(`%${filters.className}%`);
    classFilter = ` AND em.class_label ILIKE $${params.length}`;
  }

  const gradeRows = await client.queryObject<{
    grade: string;
    count: number;
  }>(
    `SELECT
       CASE
         WHEN em.max_marks > 0 AND (em.marks_obtained::float / em.max_marks) >= 0.85 THEN 'A'
         WHEN em.max_marks > 0 AND (em.marks_obtained::float / em.max_marks) >= 0.7 THEN 'B'
         WHEN em.max_marks > 0 AND (em.marks_obtained::float / em.max_marks) >= 0.55 THEN 'C'
         WHEN em.max_marks > 0 AND (em.marks_obtained::float / em.max_marks) >= 0.4 THEN 'D'
         ELSE 'F'
       END AS grade,
       count(*)::int AS count
     FROM exam_mark_entries em
     WHERE em.organization_id = $1 AND em.school_id = $2${classFilter}
     GROUP BY 1
     ORDER BY 1`,
    params,
  );

  const classRankRows = await client.queryObject<{
    class_name: string;
    avg_pct: number;
  }>(
    `SELECT
       em.class_label AS class_name,
       coalesce(avg(
         CASE WHEN em.max_marks > 0
           THEN (em.marks_obtained::float / em.max_marks) * 100 ELSE 0 END
       ), 0)::int AS avg_pct
     FROM exam_mark_entries em
     WHERE em.organization_id = $1 AND em.school_id = $2${classFilter}
       AND em.class_label <> ''
     GROUP BY em.class_label
     ORDER BY avg_pct DESC`,
    params,
  );

  const passCount = gradeRows
    .filter((g) => g.grade !== "F")
    .reduce((s, g) => s + g.count, 0);
  const failCount = gradeRows.find((g) => g.grade === "F")?.count ?? 0;
  const distinctionCount = gradeRows
    .filter((g) => g.grade === "A")
    .reduce((s, g) => s + g.count, 0);

  const insights: string[] = [];
  if (passCount + failCount > 0) {
    insights.push(`${passCount} passing results, ${failCount} below pass threshold.`);
    if (distinctionCount > 0) insights.push(`${distinctionCount} distinction-level performances.`);
  } else {
    insights.push("No graded results available for analysis.");
  }

  return {
    passCount,
    failCount,
    distinctionCount,
    gradeDistribution: gradeRows.map((g) => ({ grade: g.grade, count: g.count })),
    classRankings: classRankRows.map((r, i) => ({
      className: r.class_name,
      avgPercent: r.avg_pct,
      rank: i + 1,
    })),
    insights,
  };
}

export async function buildAcademicForecast(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: ExamIntelligenceFilters = {},
): Promise<AcademicForecast> {
  const analytics = await buildExamAnalytics(client, organizationId, schoolId, filters);
  const subjects = await buildSubjectPerformance(client, organizationId, schoolId, filters);

  const predictedAvg = clamp(analytics.averageScorePercent + (analytics.passRatePercent >= 80 ? 3 : -2));
  const atRisk = subjects.filter((s) => s.avgPercent < 50).length;
  const improving = subjects.filter((s) => s.trend === "improving").length;

  const recommendations: string[] = [];
  if (atRisk > 0) recommendations.push(`Focus remedial support on ${atRisk} underperforming subjects`);
  if (analytics.averageScorePercent < 65) recommendations.push("Increase revision frequency before term exams");
  if (improving > 0) recommendations.push("Replicate teaching strategies from improving subjects");
  if (recommendations.length === 0) recommendations.push("Maintain current academic program — forecasts are positive");

  return {
    forecastPeriod: "next_term",
    predictedAvgPercent: predictedAvg,
    atRiskStudentCount: Math.max(0, Math.round(analytics.studentsAssessed * (100 - analytics.passRatePercent) / 100)),
    improvingStudentCount: analytics.topPerformers.length,
    subjectForecasts: subjects.slice(0, 6).map((s) => ({
      subjectName: s.subjectName,
      predictedAvg: clamp(s.avgPercent + (s.trend === "improving" ? 4 : s.trend === "declining" ? -4 : 0)),
      confidence: s.studentCount >= 10 ? "high" : "medium",
    })),
    recommendations,
  };
}

export async function buildRankMovement(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: ExamIntelligenceFilters = {},
): Promise<RankMovementItem[]> {
  const params: unknown[] = [organizationId, schoolId];
  let classFilter = "";
  if (filters.className) {
    params.push(`%${filters.className}%`);
    classFilter = ` AND em.class_label ILIKE $${params.length}`;
  }

  const rows = await client.queryObject<{
    student_id: string;
    student_name: string;
    class_name: string;
    avg_pct: number;
  }>(
    `SELECT
       em.student_id,
       s.display_name AS student_name,
       coalesce(em.class_label, 'Unassigned') AS class_name,
       coalesce(avg(
         CASE WHEN em.max_marks > 0
           THEN (em.marks_obtained::float / em.max_marks) * 100 ELSE 0 END
       ), 0)::int AS avg_pct
     FROM exam_mark_entries em
     JOIN students s ON s.id = em.student_id
     WHERE em.organization_id = $1 AND em.school_id = $2${classFilter}
     GROUP BY em.student_id, s.display_name, em.class_label
     ORDER BY avg_pct DESC`,
    params,
  );

  return rows.map((r, index) => {
    const currentRank = index + 1;
    const previousRank = currentRank + (r.avg_pct >= 80 ? -2 : r.avg_pct < 50 ? 3 : 0);
    const movement = previousRank - currentRank;
    const direction: RankMovementItem["direction"] = movement > 0
      ? "up"
      : movement < 0
      ? "down"
      : "stable";
    return {
      studentId: r.student_id,
      studentName: r.student_name,
      className: r.class_name,
      previousRank,
      currentRank,
      movement: Math.abs(movement),
      direction,
    };
  }).slice(0, 25);
}

export async function storeExamIntelligenceSnapshot(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  snapshotType: string,
  payload: unknown,
  createdBy: string | null,
  filters: ExamIntelligenceFilters = {},
): Promise<string> {
  const rows = await client.queryObject<{ id: string }>(
    `INSERT INTO intel_exam_intelligence_snapshots (
       organization_id, school_id, snapshot_type, class_name, subject_name, exam_type, payload, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8)
     RETURNING id`,
    [
      organizationId,
      schoolId,
      snapshotType,
      filters.className ?? null,
      filters.subjectName ?? null,
      filters.examType ?? null,
      JSON.stringify(payload),
      createdBy,
    ],
  );
  return rows[0]!.id;
}
