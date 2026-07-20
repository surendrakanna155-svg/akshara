/** Management (executive) contracts — mirror lib/features/management/management_models.dart. */
export type ManagementApprovalType = 'budget' | 'expense' | 'payroll' | 'vendor' | 'marketing' | 'admission';
export type ManagementApprovalStatus = 'pending' | 'approved' | 'rejected';
export type ManagementAiRecommendation = 'approve' | 'review' | 'reject';

export interface ManagementKpi {
  id: string;
  label: string;
  value: string;
  detail?: string;
  accentName?: string;
  drillRoute?: string;
}

export interface ManagementApprovalItem {
  id: string;
  type: ManagementApprovalType;
  title: string;
  requester: string;
  amount: string;
  dateLabel: string;
  status: ManagementApprovalStatus;
  aiRecommendation: ManagementAiRecommendation;
}

export interface ManagementFunnelStage {
  label: string;
  count: number;
  percent: number;
}

export interface ManagementClassSummaryRow {
  classLabel: string;
  students: number;
  attendancePercent: string;
  avgMarks: string;
  feeCollectionPercent: string;
  teachers: number;
}

export interface ManagementKpiData {
  kpis: ManagementKpi[];
}

export interface ManagementDashboardData extends ManagementKpiData {
  approvals?: ManagementApprovalItem[];
}

export interface ManagementFunnelData extends ManagementKpiData {
  funnelStages: ManagementFunnelStage[];
}

export interface ManagementAnalyticsData extends ManagementKpiData {
  classSummary?: ManagementClassSummaryRow[];
}
