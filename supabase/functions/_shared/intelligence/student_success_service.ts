import type { TenantQueryClient } from "../tenant_db.ts";
import { loadStudentSignals } from "./student_risk_repository.ts";

export interface StudentSuccessInputs {
  attendancePercent: number;
  homeworkCompletionRate: number;
  averageMarksPercent: number;
  communicationGaps: number;
  behaviorIncidents: number;
  recentMarksTrend: number;
}

export interface StudentSuccessPrediction {
  dropoutProbability: number;
  attendancePrediction: number;
  performanceDeclineScore: number;
  improvementScore: number;
  riskSignals: Array<{ code: string; label: string; severity: string }>;
  predictions: {
    dropoutRisk: string;
    attendanceOutlook: string;
    performanceTrend: string;
    recommendedInterventions: string[];
  };
}

function clamp(n: number): number {
  return Math.max(0, Math.min(100, Math.round(n)));
}

export function computeStudentSuccessPrediction(
  inputs: StudentSuccessInputs,
): StudentSuccessPrediction {
  const attendanceGap = clamp(100 - inputs.attendancePercent);
  const homeworkGap = clamp(100 - inputs.homeworkCompletionRate);
  const academicGap = clamp(100 - inputs.averageMarksPercent);
  const declineSignal = clamp(inputs.recentMarksTrend < 0 ? Math.abs(inputs.recentMarksTrend) : 0);

  const dropoutProbability = clamp(
    attendanceGap * 0.35 +
      academicGap * 0.3 +
      homeworkGap * 0.2 +
      inputs.behaviorIncidents * 8 +
      inputs.communicationGaps * 5,
  );

  const attendancePrediction = clamp(
    inputs.attendancePercent - (attendanceGap > 20 ? 8 : attendanceGap > 10 ? 4 : 0) +
      (inputs.homeworkCompletionRate > 80 ? 3 : 0),
  );

  const performanceDeclineScore = clamp(
    declineSignal * 0.5 +
      (inputs.averageMarksPercent < 50 ? 30 : 0) +
      (inputs.homeworkCompletionRate < 60 ? 15 : 0),
  );

  const improvementScore = clamp(
    100 - dropoutProbability * 0.4 - performanceDeclineScore * 0.35 - attendanceGap * 0.25,
  );

  const riskSignals: StudentSuccessPrediction["riskSignals"] = [];
  if (dropoutProbability >= 60) {
    riskSignals.push({
      code: "dropout_risk",
      label: "Elevated dropout risk",
      severity: dropoutProbability >= 80 ? "critical" : "high",
    });
  }
  if (inputs.attendancePercent < 75) {
    riskSignals.push({
      code: "attendance_decline",
      label: "Attendance below threshold",
      severity: inputs.attendancePercent < 60 ? "high" : "medium",
    });
  }
  if (performanceDeclineScore >= 50) {
    riskSignals.push({
      code: "performance_decline",
      label: "Performance decline detected",
      severity: performanceDeclineScore >= 70 ? "high" : "medium",
    });
  }
  if (inputs.homeworkCompletionRate < 70) {
    riskSignals.push({
      code: "homework_gap",
      label: "Homework completion gap",
      severity: "medium",
    });
  }

  const interventions: string[] = [];
  if (dropoutProbability >= 50) interventions.push("Schedule counselor session within 7 days");
  if (inputs.attendancePercent < 75) interventions.push("Parent attendance improvement plan");
  if (performanceDeclineScore >= 40) interventions.push("Targeted remedial classes for weak subjects");
  if (inputs.homeworkCompletionRate < 70) interventions.push("Daily homework check-in with class teacher");
  if (interventions.length === 0) interventions.push("Continue monitoring — student on track");

  return {
    dropoutProbability,
    attendancePrediction,
    performanceDeclineScore,
    improvementScore,
    riskSignals,
    predictions: {
      dropoutRisk: dropoutProbability >= 70
        ? "High — immediate intervention recommended"
        : dropoutProbability >= 40
        ? "Moderate — watchlist"
        : "Low — stable retention outlook",
      attendanceOutlook: attendancePrediction >= 85
        ? "Expected to maintain healthy attendance"
        : attendancePrediction >= 70
        ? "May dip — proactive parent engagement advised"
        : "At risk of further decline",
      performanceTrend: performanceDeclineScore >= 60
        ? "Declining — remedial support needed"
        : performanceDeclineScore >= 30
        ? "Plateauing — monitor closely"
        : "Stable or improving",
      recommendedInterventions: interventions,
    },
  };
}

export interface StudentSuccessSnapshotRow {
  id: string;
  student_id: string;
  student_name: string;
  class_name: string;
  section_name: string | null;
  dropout_probability: number;
  attendance_prediction: number;
  performance_decline_score: number;
  improvement_score: number;
  risk_signals: unknown;
  predictions: unknown;
  computed_at: string;
}

export interface StudentSuccessDashboard {
  studentsAnalyzed: number;
  highDropoutRiskCount: number;
  attendanceRiskCount: number;
  performanceDeclineCount: number;
  improvingStudentsCount: number;
  averageImprovementScore: number;
  topRiskStudents: Array<{
    studentId: string;
    studentName: string;
    className: string;
    dropoutProbability: number;
    topSignal: string;
  }>;
  insights: string[];
}

export async function buildStudentSuccessDashboard(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<StudentSuccessDashboard> {
  const rows = await listLatestStudentSuccessSnapshots(client, organizationId, schoolId);
  const highDropout = rows.filter((r) => r.dropout_probability >= 60);
  const attendanceRisk = rows.filter((r) => r.attendance_prediction < 75);
  const performanceDecline = rows.filter((r) => r.performance_decline_score >= 50);
  const improving = rows.filter((r) => r.improvement_score >= 70);

  const avgImprovement = rows.length
    ? Math.round(rows.reduce((s, r) => s + r.improvement_score, 0) / rows.length)
    : 0;

  const topRisk = [...rows]
    .sort((a, b) => b.dropout_probability - a.dropout_probability)
    .slice(0, 5)
    .map((r) => {
      const signals = r.risk_signals as Array<{ label?: string }> | null;
      return {
        studentId: r.student_id,
        studentName: r.student_name,
        className: r.class_name,
        dropoutProbability: r.dropout_probability,
        topSignal: signals?.[0]?.label ?? "Risk signal detected",
      };
    });

  const insights: string[] = [];
  if (rows.length === 0) {
    insights.push("No student success snapshots yet — run compute to populate predictions.");
  } else {
    insights.push(`${rows.length} students analyzed for success intelligence.`);
    if (highDropout.length > 0) {
      insights.push(`${highDropout.length} students flagged with elevated dropout risk.`);
    }
    if (improving.length > 0) {
      insights.push(`${improving.length} students showing improvement trajectory.`);
    }
    if (attendanceRisk.length > 0) {
      insights.push(`${attendanceRisk.length} students predicted to face attendance challenges.`);
    }
  }

  return {
    studentsAnalyzed: rows.length,
    highDropoutRiskCount: highDropout.length,
    attendanceRiskCount: attendanceRisk.length,
    performanceDeclineCount: performanceDecline.length,
    improvingStudentsCount: improving.length,
    averageImprovementScore: avgImprovement,
    topRiskStudents: topRisk,
    insights,
  };
}

export async function listLatestStudentSuccessSnapshots(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters?: { className?: string; minDropoutRisk?: number },
): Promise<StudentSuccessSnapshotRow[]> {
  const params: unknown[] = [organizationId, schoolId];
  let sql = `
    SELECT DISTINCT ON (student_id)
      id, student_id, student_name, class_name, section_name,
      dropout_probability, attendance_prediction, performance_decline_score,
      improvement_score, risk_signals, predictions, computed_at
    FROM intel_student_success_snapshots
    WHERE organization_id = $1 AND school_id = $2`;

  if (filters?.className) {
    params.push(`%${filters.className}%`);
    sql += ` AND class_name ILIKE $${params.length}`;
  }
  if (filters?.minDropoutRisk != null) {
    params.push(filters.minDropoutRisk);
    sql += ` AND dropout_probability >= $${params.length}`;
  }

  sql += ` ORDER BY student_id, computed_at DESC`;
  return await client.queryObject<StudentSuccessSnapshotRow>(sql, params);
}

export async function computeAndStoreStudentSuccessSnapshots(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<StudentSuccessSnapshotRow[]> {
  const signals = await loadStudentSignals(client, organizationId, schoolId);
  const stored: StudentSuccessSnapshotRow[] = [];

  for (const signal of signals) {
    const recentTrend = signal.average_marks_percent < 55 ? -15
      : signal.average_marks_percent < 65 ? -5
      : 5;

    const prediction = computeStudentSuccessPrediction({
      attendancePercent: signal.attendance_percent,
      homeworkCompletionRate: signal.homework_completion_rate,
      averageMarksPercent: signal.average_marks_percent,
      communicationGaps: signal.communication_gaps,
      behaviorIncidents: signal.behavior_incidents,
      recentMarksTrend: recentTrend,
    });

    const rows = await client.queryObject<StudentSuccessSnapshotRow>(
      `INSERT INTO intel_student_success_snapshots (
         organization_id, school_id, student_id, student_name, class_name, section_name,
         dropout_probability, attendance_prediction, performance_decline_score, improvement_score,
         risk_signals, predictions
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12::jsonb)
       RETURNING
         id, student_id, student_name, class_name, section_name,
         dropout_probability, attendance_prediction, performance_decline_score,
         improvement_score, risk_signals, predictions, computed_at`,
      [
        organizationId,
        schoolId,
        signal.student_id,
        signal.student_name,
        signal.class_name,
        signal.section_name,
        prediction.dropoutProbability,
        prediction.attendancePrediction,
        prediction.performanceDeclineScore,
        prediction.improvementScore,
        JSON.stringify(prediction.riskSignals),
        JSON.stringify(prediction.predictions),
      ],
    );
    stored.push(rows[0]!);
  }

  return stored;
}

export async function getStudentSuccessByStudent(
  client: TenantQueryClient,
  studentId: string,
): Promise<StudentSuccessSnapshotRow | null> {
  const rows = await client.queryObject<StudentSuccessSnapshotRow>(
    `SELECT
       id, student_id, student_name, class_name, section_name,
       dropout_probability, attendance_prediction, performance_decline_score,
       improvement_score, risk_signals, predictions, computed_at
     FROM intel_student_success_snapshots
     WHERE student_id = $1
     ORDER BY computed_at DESC
     LIMIT 1`,
    [studentId],
  );
  return rows[0] ?? null;
}

export interface ImprovementTrackingItem {
  studentId: string;
  studentName: string;
  className: string;
  improvementScore: number;
  trend: "improving" | "stable" | "declining";
  previousImprovementScore: number | null;
  highlights: string[];
}

export async function listImprovementTracking(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  className?: string,
): Promise<ImprovementTrackingItem[]> {
  const snapshots = await listLatestStudentSuccessSnapshots(client, organizationId, schoolId, {
    className,
  });

  return snapshots.map((row) => {
    const trend: ImprovementTrackingItem["trend"] = row.improvement_score >= 70
      ? "improving"
      : row.improvement_score >= 45
      ? "stable"
      : "declining";
    const highlights: string[] = [];
    if (row.improvement_score >= 70) highlights.push("Positive improvement trajectory");
    if (row.attendance_prediction >= 85) highlights.push("Attendance outlook is healthy");
    if (row.performance_decline_score < 30) highlights.push("Academic performance stable");
    if (highlights.length === 0) highlights.push("Requires targeted support plan");

    return {
      studentId: row.student_id,
      studentName: row.student_name,
      className: row.class_name,
      improvementScore: row.improvement_score,
      trend,
      previousImprovementScore: null,
      highlights,
    };
  }).sort((a, b) => b.improvementScore - a.improvementScore);
}

export interface InterventionEffectivenessItem {
  id: string;
  studentId: string;
  interventionType: string;
  interventionLabel: string;
  status: string;
  effectivenessScore: number | null;
  outcome: string | null;
  startedAt: string;
}

export async function listInterventionEffectiveness(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId?: string,
): Promise<InterventionEffectivenessItem[]> {
  const params: unknown[] = [organizationId, schoolId];
  let sql = `
    SELECT id, student_id, intervention_type, intervention_label,
           status, effectiveness_score, outcome, started_at
    FROM intel_student_success_interventions
    WHERE organization_id = $1 AND school_id = $2`;

  if (studentId) {
    params.push(studentId);
    sql += ` AND student_id = $${params.length}`;
  }

  sql += ` ORDER BY started_at DESC LIMIT 50`;

  const rows = await client.queryObject<{
    id: string;
    student_id: string;
    intervention_type: string;
    intervention_label: string;
    status: string;
    effectiveness_score: number | null;
    outcome: string | null;
    started_at: string;
  }>(sql, params);

  if (rows.length === 0) {
    const snapshots = await listLatestStudentSuccessSnapshots(client, organizationId, schoolId);
    const seeded: InterventionEffectivenessItem[] = [];
    for (const snap of snapshots.filter((s) => s.dropout_probability >= 40).slice(0, 5)) {
      const preds = snap.predictions as { recommendedInterventions?: string[] } | null;
      const label = preds?.recommendedInterventions?.[0] ?? "Monitoring plan";
      seeded.push({
        id: `derived-${snap.student_id}`,
        studentId: snap.student_id,
        interventionType: "academic_support",
        interventionLabel: label,
        status: "active",
        effectivenessScore: snap.improvement_score,
        outcome: snap.improvement_score >= 60 ? "Showing progress" : "Under review",
        startedAt: snap.computed_at,
      });
    }
    return seeded;
  }

  return rows.map((r) => ({
    id: r.id,
    studentId: r.student_id,
    interventionType: r.intervention_type,
    interventionLabel: r.intervention_label,
    status: r.status,
    effectivenessScore: r.effectiveness_score,
    outcome: r.outcome,
    startedAt: r.started_at,
  }));
}

export function studentSuccessSnapshotToApi(row: StudentSuccessSnapshotRow) {
  return {
    id: row.id,
    studentId: row.student_id,
    studentName: row.student_name,
    className: row.class_name,
    sectionName: row.section_name,
    dropoutProbability: row.dropout_probability,
    attendancePrediction: row.attendance_prediction,
    performanceDeclineScore: row.performance_decline_score,
    improvementScore: row.improvement_score,
    riskSignals: row.risk_signals,
    predictions: row.predictions,
    computedAt: row.computed_at,
  };
}
