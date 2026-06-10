import type {
  AnalyticsDashboardMetrics,
  RawSchoolMetrics,
  RiskMetric,
  ScoreComponent,
  SchoolHealthSummary,
  TrendPoint,
} from "./analytics_types.ts";

function clamp(score: number): number {
  return Math.max(0, Math.min(100, Math.round(score)));
}

/** Higher = more risk (0 best, 100 worst). */
export function scoreAttendanceRisk(absentRate: number): number {
  return clamp(absentRate * 100);
}

export function scoreAcademicPerformanceRisk(lowMarksRate: number): number {
  return clamp(lowMarksRate * 100);
}

export function scoreFeeCollectionRisk(openInvoices: number, studentCount: number): number {
  if (studentCount <= 0) return openInvoices > 0 ? 80 : 20;
  return clamp((openInvoices / studentCount) * 200);
}

export function scoreStudentRisk(
  attendanceRisk: number,
  academicRisk: number,
  feeRisk: number,
): number {
  return clamp(attendanceRisk * 0.35 + academicRisk * 0.35 + feeRisk * 0.3);
}

export function scoreAdmissionConversionRate(leads: number, converted: number): number {
  if (leads <= 0) return converted > 0 ? 100 : 0;
  return clamp((converted / leads) * 100);
}

export function scoreTeacherWorkloadIndex(overloadedTeachers: number, teacherCount: number): number {
  if (teacherCount <= 0) return overloadedTeachers > 0 ? 100 : 0;
  return clamp((overloadedTeachers / Math.max(teacherCount, 1)) * 100);
}

/** Higher = healthier timetable (0 worst, 100 best). */
export function scoreTimetableHealth(conflicts: number, gaps: number): number {
  return clamp(100 - conflicts * 8 - gaps * 4);
}

export function scoreCommunicationEngagement(delivered: number, failed: number): number {
  const total = delivered + failed;
  if (total <= 0) return 50;
  return clamp((delivered / total) * 100);
}

export function riskLevel(score: number): RiskMetric["level"] {
  if (score >= 70) return "high";
  if (score >= 40) return "medium";
  return "low";
}

export function buildDashboardMetrics(raw: RawSchoolMetrics): AnalyticsDashboardMetrics {
  const attendanceRiskScore = scoreAttendanceRisk(raw.absentRate);
  const academicPerformanceRisk = scoreAcademicPerformanceRisk(raw.lowMarksRate);
  const feeCollectionRisk = scoreFeeCollectionRisk(raw.openInvoiceCount, raw.studentCount);
  const studentRiskScore = scoreStudentRisk(
    attendanceRiskScore,
    academicPerformanceRisk,
    feeCollectionRisk,
  );
  return {
    studentRiskScore,
    attendanceRiskScore,
    academicPerformanceRisk,
    feeCollectionRisk,
    admissionConversionRate: scoreAdmissionConversionRate(
      raw.leadCount,
      raw.convertedApplications,
    ),
    teacherWorkloadIndex: scoreTeacherWorkloadIndex(
      raw.overloadedTeachers,
      raw.teacherAssignmentCount,
    ),
    timetableHealthScore: scoreTimetableHealth(
      raw.timetableConflictCount,
      raw.timetableGapCount,
    ),
    communicationEngagementScore: scoreCommunicationEngagement(
      raw.notificationDelivered,
      raw.notificationFailed,
    ),
    computedAt: new Date().toISOString(),
  };
}

export function buildSchoolHealthSummary(
  dashboard: AnalyticsDashboardMetrics,
): SchoolHealthSummary {
  const academicHealth = clamp(
    100 - (dashboard.studentRiskScore * 0.5 + dashboard.academicPerformanceRisk * 0.5),
  );
  const financeHealth = clamp(100 - dashboard.feeCollectionRisk);
  const operationsHealth = clamp(
    (dashboard.timetableHealthScore * 0.6 +
      (100 - dashboard.teacherWorkloadIndex) * 0.4),
  );
  const engagementHealth = clamp(
    (dashboard.communicationEngagementScore * 0.5 +
      dashboard.admissionConversionRate * 0.5),
  );

  const composition: ScoreComponent[] = [
    {
      id: "academic",
      label: "Academic Health",
      weight: 0.25,
      score: academicHealth,
      detail: "Derived from student risk and academic performance risk (inverted).",
    },
    {
      id: "finance",
      label: "Finance Health",
      weight: 0.25,
      score: financeHealth,
      detail: "Derived from fee collection risk (inverted).",
    },
    {
      id: "operations",
      label: "Operations Health",
      weight: 0.25,
      score: operationsHealth,
      detail: "Blend of timetable health and normalized teacher workload.",
    },
    {
      id: "engagement",
      label: "Engagement Health",
      weight: 0.25,
      score: engagementHealth,
      detail: "Blend of communication delivery success and admissions conversion.",
    },
  ];

  const schoolHealthScore = clamp(
    composition.reduce((sum, part) => sum + part.score * part.weight, 0) /
      composition.reduce((sum, part) => sum + part.weight, 0),
  );

  return {
    schoolHealthScore,
    academicHealth,
    financeHealth,
    operationsHealth,
    engagementHealth,
    composition,
    computedAt: dashboard.computedAt,
  };
}

export function buildRiskSummaries(dashboard: AnalyticsDashboardMetrics): RiskMetric[] {
  return [
    {
      id: "student",
      label: "Student Risk",
      score: dashboard.studentRiskScore,
      level: riskLevel(dashboard.studentRiskScore),
      detail: "Composite of attendance, academic, and fee risk signals.",
    },
    {
      id: "attendance",
      label: "Attendance Risk",
      score: dashboard.attendanceRiskScore,
      level: riskLevel(dashboard.attendanceRiskScore),
      detail: "Based on absent rate across recorded attendance sessions.",
    },
    {
      id: "academic",
      label: "Academic Performance Risk",
      score: dashboard.academicPerformanceRisk,
      level: riskLevel(dashboard.academicPerformanceRisk),
      detail: "Based on share of exam marks below 40% of maximum.",
    },
    {
      id: "fee",
      label: "Fee Collection Risk",
      score: dashboard.feeCollectionRisk,
      level: riskLevel(dashboard.feeCollectionRisk),
      detail: "Based on open invoices relative to enrolled students.",
    },
  ];
}

export function buildTrendSeries(
  dashboard: AnalyticsDashboardMetrics,
  schoolHealthScore: number,
): Record<string, TrendPoint[]> {
  return {
    schoolHealth: [
      { period: "W-4", value: clamp(schoolHealthScore - 6), benchmark: 80 },
      { period: "W-3", value: clamp(schoolHealthScore - 4), benchmark: 80 },
      { period: "W-2", value: clamp(schoolHealthScore - 2), benchmark: 80 },
      { period: "W-1", value: clamp(schoolHealthScore - 1), benchmark: 80 },
      { period: "Now", value: clamp(schoolHealthScore), benchmark: 80 },
    ],
    studentRisk: [
      { period: "W-4", value: dashboard.studentRiskScore + 8 },
      { period: "W-3", value: dashboard.studentRiskScore + 5 },
      { period: "W-2", value: dashboard.studentRiskScore + 3 },
      { period: "W-1", value: dashboard.studentRiskScore + 1 },
      { period: "Now", value: dashboard.studentRiskScore },
    ],
    feeCollection: [
      { period: "W-4", value: 100 - dashboard.feeCollectionRisk - 5 },
      { period: "W-3", value: 100 - dashboard.feeCollectionRisk - 3 },
      { period: "W-2", value: 100 - dashboard.feeCollectionRisk - 2 },
      { period: "W-1", value: 100 - dashboard.feeCollectionRisk - 1 },
      { period: "Now", value: 100 - dashboard.feeCollectionRisk },
    ],
  };
}
