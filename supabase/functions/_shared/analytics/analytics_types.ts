export interface ScoreComponent {
  id: string;
  label: string;
  weight: number;
  score: number;
  detail: string;
}

export interface RiskMetric {
  id: string;
  label: string;
  score: number;
  level: "low" | "medium" | "high";
  detail: string;
}

export interface TrendPoint {
  period: string;
  value: number;
  benchmark?: number;
}

export interface AnalyticsDashboardMetrics {
  studentRiskScore: number;
  attendanceRiskScore: number;
  academicPerformanceRisk: number;
  feeCollectionRisk: number;
  admissionConversionRate: number;
  teacherWorkloadIndex: number;
  timetableHealthScore: number;
  communicationEngagementScore: number;
  computedAt: string;
}

export interface SchoolHealthSummary {
  schoolHealthScore: number;
  academicHealth: number;
  financeHealth: number;
  operationsHealth: number;
  engagementHealth: number;
  composition: ScoreComponent[];
  computedAt: string;
}

export interface AnalyticsRecommendation {
  kind: string;
  title: string;
  detail: string;
  readOnly: true;
}

export interface PrincipalSummary {
  headline: string;
  highlights: string[];
  risks: string[];
  recommendations: AnalyticsRecommendation[];
  computedAt: string;
}

export interface WeeklyBriefing {
  weekLabel: string;
  sections: Array<{ title: string; bullets: string[] }>;
  readOnly: true;
  computedAt: string;
}

export interface RawSchoolMetrics {
  studentCount: number;
  enrollmentCount: number;
  absentRate: number;
  lowMarksRate: number;
  openInvoiceCount: number;
  completedCollections: number;
  leadCount: number;
  convertedApplications: number;
  timetableConflictCount: number;
  timetableGapCount: number;
  overloadedTeachers: number;
  notificationDelivered: number;
  notificationFailed: number;
  teacherAssignmentCount: number;
}
