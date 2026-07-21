import type { TenantQueryClient } from "../tenant_db.ts";
import { loadStudentSignals } from "./student_risk_repository.ts";
import type { MonitoringCompleteness } from "./student_risk_repository.ts";

// SAFEGUARDING (ICA-H4). An UNMONITORED student (no attendance data) cannot be
// scored from monitoring signals, so the optimistic outputs are untrustworthy.
// Floor dropout onto the review watchlist and cap improvement out of the
// "improving" bucket, so such a student is surfaced for review — never
// low-concern / "improving" by default. These mirror UNMONITORED_REVIEW_SCORE
// (=40) in student_risk_repository.ts (the risk "medium" / dropout "watchlist"
// threshold); that constant is not exported, so the values are mirrored locally
// and a shared extraction is a tidy follow-up. Both are valid integers within
// the intel_student_success_snapshots CHECK (col BETWEEN 0 AND 100) bounds.
const UNMONITORED_DROPOUT_FLOOR = 40; // >= "Moderate — watchlist", never "Low — stable"
const UNMONITORED_IMPROVEMENT_CAP = 45; // below the "improving" (>= 70) bucket

export interface StudentSuccessInputs {
  attendancePercent: number;
  homeworkCompletionRate: number;
  averageMarksPercent: number;
  communicationGaps: number;
  behaviorIncidents: number;
  recentMarksTrend: number;
  // SAFEGUARDING (ICA-H4): monitoring provenance. Defaults (true / not
  // unmonitored) preserve the historical behaviour for callers with fully
  // measured data. When a dimension has NO data it is EXCLUDED from the
  // computation instead of being treated as a fabricated optimistic 100 (which
  // would inflate the optimism scores). When the dominant attendance signal is
  // absent the student is UNMONITORED and the outputs are floored to a "needs
  // review" posture.
  attendanceHasData?: boolean;
  homeworkHasData?: boolean;
  dataCompleteness?: MonitoringCompleteness;
  unmonitored?: boolean;
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
    // SAFEGUARDING (ICA-H4): monitoring provenance carried on the prediction so
    // it can be persisted (intel_student_success_snapshots has no `inputs`
    // column) and surfaced by the UI — a no-data student must read as "needs
    // review", never silently low-concern.
    unmonitored: boolean;
    dataCompleteness: MonitoringCompleteness;
    attendanceHasData: boolean;
    homeworkHasData: boolean;
    monitoringCaveat: string | null;
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

  let dropoutProbability = clamp(
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

  let improvementScore = clamp(
    100 - dropoutProbability * 0.4 - performanceDeclineScore * 0.35 - attendanceGap * 0.25,
  );

  // ── SAFEGUARDING (ICA-H4) ──────────────────────────────────────────────────
  // A missing monitoring dimension was already fed as a gap-0 placeholder (100)
  // by loadStudentSignals, so it contributes NOTHING to the arithmetic above
  // rather than a fabricated optimistic value. But when the dominant attendance
  // signal is absent the student is UNMONITORED and these optimistic outputs are
  // untrustworthy: floor dropout onto the review watchlist and cap improvement
  // out of the "improving" bucket, so the student is surfaced for review — never
  // low-concern / "improving" by default. Mirrors the unmonitored handling in
  // computeAndStoreRiskSnapshots (student_risk_repository.ts). The floor/cap are
  // applied AFTER the raw scores are computed so a floored dropout does not feed
  // back into the improvement formula.
  const attendanceHasData = inputs.attendanceHasData !== false;
  const homeworkHasData = inputs.homeworkHasData !== false;
  const dataCompleteness: MonitoringCompleteness = inputs.dataCompleteness ??
    (attendanceHasData && homeworkHasData
      ? "full"
      : (!attendanceHasData && !homeworkHasData ? "none" : "partial"));
  const unmonitored = inputs.unmonitored ?? !attendanceHasData;
  if (unmonitored) {
    dropoutProbability = Math.max(dropoutProbability, UNMONITORED_DROPOUT_FLOOR);
    improvementScore = Math.min(improvementScore, UNMONITORED_IMPROVEMENT_CAP);
  }

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
  // SAFEGUARDING (ICA-H4): surface a monitoring-provenance caveat. For an
  // unmonitored student it goes FIRST so the dashboard's top-signal reflects the
  // real reason (no data), not a coincidental low-signal read.
  if (unmonitored) {
    riskSignals.unshift({
      code: "no_monitoring_data",
      label: "No monitoring data",
      severity: "medium",
    });
  } else if (dataCompleteness === "partial") {
    riskSignals.push({
      code: "partial_monitoring_data",
      label: "Partial monitoring data",
      severity: "low",
    });
  }

  const interventions: string[] = [];
  // SAFEGUARDING (ICA-H4): an unmonitored student cannot be assessed — recommend
  // collecting data instead of ever falling through to "on track".
  if (unmonitored) {
    interventions.push(
      "Collect attendance/homework data — student is unmonitored and cannot be assessed",
    );
  }
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
      // SAFEGUARDING (ICA-H4): monitoring provenance persisted in the predictions
      // jsonb (no `inputs` column on this table) so the UI can distinguish a real
      // measurement from an ABSENCE of data and show the caveat.
      unmonitored,
      dataCompleteness,
      attendanceHasData,
      homeworkHasData,
      monitoringCaveat: unmonitored
        ? "No attendance has been marked for this student, so success cannot be assessed from monitoring data. Flagged for review — not confirmed on-track."
        : dataCompleteness === "partial"
        ? "Some monitoring data is missing; predictions reflect the available signals only."
        : null,
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
      // SAFEGUARDING (ICA-H4): forward the monitoring-provenance flags so a
      // no-attendance-data student is floored to "needs review" (never
      // low-concern / "improving") instead of scoring optimistically off the
      // gap-0 placeholders that loadStudentSignals feeds for missing dimensions.
      attendanceHasData: signal.attendance_has_data,
      homeworkHasData: signal.homework_has_data,
      dataCompleteness: signal.data_completeness,
      unmonitored: signal.unmonitored,
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
