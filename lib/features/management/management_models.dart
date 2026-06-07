import 'package:flutter/material.dart';

/// Management sub-module destinations (MG-01 → MG-08).
enum ManagementScreen {
  dashboard,
  analytics,
  admissions,
  finance,
  academics,
  performance,
  tasks,
  settings;

  String get label => switch (this) {
        ManagementScreen.dashboard => 'Dashboard',
        ManagementScreen.analytics => 'Analytics',
        ManagementScreen.admissions => 'Admissions',
        ManagementScreen.finance => 'Finance',
        ManagementScreen.academics => 'Academics',
        ManagementScreen.performance => 'Performance',
        ManagementScreen.tasks => 'Tasks',
        ManagementScreen.settings => 'Settings',
      };
}

enum ManagementApprovalType { budget, expense, payroll, vendor, marketing, admission }

enum ManagementApprovalStatus { pending, approved, rejected }

enum ManagementAiRecommendation { approve, review, reject }

@immutable
class ManagementKpi {
  const ManagementKpi({
    required this.id,
    required this.value,
    required this.label,
    required this.icon,
    required this.accentName,
    this.detail,
  });

  final String id;
  final String value;
  final String label;
  final IconData icon;
  final String accentName;
  final String? detail;
}

@immutable
class ManagementTrendPoint {
  const ManagementTrendPoint({
    required this.label,
    required this.amountLakhs,
    required this.targetLakhs,
  });

  final String label;
  final double amountLakhs;
  final double targetLakhs;
}

@immutable
class ManagementSegment {
  const ManagementSegment({
    required this.label,
    required this.value,
    required this.percent,
  });

  final String label;
  final double value;
  final double percent;
}

@immutable
class ManagementApprovalItem {
  const ManagementApprovalItem({
    required this.id,
    required this.type,
    required this.title,
    required this.requester,
    required this.amount,
    required this.dateLabel,
    required this.status,
    required this.aiRecommendation,
    required this.sourceModuleRoute,
  });

  final String id;
  final ManagementApprovalType type;
  final String title;
  final String requester;
  final String amount;
  final String dateLabel;
  final ManagementApprovalStatus status;
  final ManagementAiRecommendation aiRecommendation;
  final String sourceModuleRoute;
}

@immutable
class ManagementAdmissionsSnapshot {
  const ManagementAdmissionsSnapshot({
    required this.leadsMtd,
    required this.confirmed,
    required this.joined,
    required this.conversionRate,
    required this.recentConversions,
  });

  final int leadsMtd;
  final int confirmed;
  final int joined;
  final String conversionRate;
  final List<ManagementRecentConversion> recentConversions;
}

@immutable
class ManagementRecentConversion {
  const ManagementRecentConversion({
    required this.id,
    required this.leadName,
    required this.classLabel,
    required this.source,
    required this.counselor,
    required this.stage,
    required this.daysInPipeline,
  });

  final String id;
  final String leadName;
  final String classLabel;
  final String source;
  final String counselor;
  final String stage;
  final int daysInPipeline;
}

@immutable
class ManagementFeeSnapshot {
  const ManagementFeeSnapshot({
    required this.collectedMtd,
    required this.outstanding,
    required this.collectionRate,
    required this.defaulters,
  });

  final String collectedMtd;
  final String outstanding;
  final String collectionRate;
  final int defaulters;
}

@immutable
class ManagementDashboardData {
  const ManagementDashboardData({
    required this.kpis,
    required this.revenueTrend,
    required this.expenseBreakdown,
    required this.approvalQueue,
    required this.admissionsSnapshot,
    required this.feeSnapshot,
    required this.aiInsight,
  });

  final List<ManagementKpi> kpis;
  final List<ManagementTrendPoint> revenueTrend;
  final List<ManagementSegment> expenseBreakdown;
  final List<ManagementApprovalItem> approvalQueue;
  final ManagementAdmissionsSnapshot admissionsSnapshot;
  final ManagementFeeSnapshot feeSnapshot;
  final String aiInsight;
}

@immutable
class ManagementClassSummaryRow {
  const ManagementClassSummaryRow({
    required this.classLabel,
    required this.students,
    required this.attendancePercent,
    required this.avgMarks,
    required this.feeCollectionPercent,
    required this.teachers,
  });

  final String classLabel;
  final int students;
  final String attendancePercent;
  final String avgMarks;
  final String feeCollectionPercent;
  final int teachers;
}

@immutable
class ManagementAnalyticsData {
  const ManagementAnalyticsData({
    required this.kpis,
    required this.enrollmentTrend,
    required this.attendanceByClass,
    required this.classSummary,
    required this.aiInsight,
  });

  final List<ManagementKpi> kpis;
  final List<ManagementTrendPoint> enrollmentTrend;
  final List<ManagementSegment> attendanceByClass;
  final List<ManagementClassSummaryRow> classSummary;
  final String aiInsight;
}

@immutable
class ManagementFunnelStage {
  const ManagementFunnelStage({
    required this.label,
    required this.count,
    required this.percent,
  });

  final String label;
  final int count;
  final double percent;
}

@immutable
class ManagementAdmissionsFunnelData {
  const ManagementAdmissionsFunnelData({
    required this.kpis,
    required this.funnelStages,
    required this.sourcePerformance,
    required this.recentConversions,
    required this.aiInsight,
    required this.admissionsReportsRoute,
  });

  final List<ManagementKpi> kpis;
  final List<ManagementFunnelStage> funnelStages;
  final List<ManagementSegment> sourcePerformance;
  final List<ManagementRecentConversion> recentConversions;
  final String aiInsight;
  final String admissionsReportsRoute;
}

@immutable
class ManagementFinanceDrillLink {
  const ManagementFinanceDrillLink({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.metric,
  });

  final String id;
  final String title;
  final String subtitle;
  final String route;
  final String metric;
}

@immutable
class ManagementFinancialHealthData {
  const ManagementFinancialHealthData({
    required this.revenue,
    required this.expenses,
    required this.netProfit,
    required this.kpis,
    required this.plTrend,
    required this.cashFlowTrend,
    required this.drillLinks,
    required this.aiInsight,
  });

  final String revenue;
  final String expenses;
  final String netProfit;
  final List<ManagementKpi> kpis;
  final List<ManagementTrendPoint> plTrend;
  final List<ManagementTrendPoint> cashFlowTrend;
  final List<ManagementFinanceDrillLink> drillLinks;
  final String aiInsight;
}

@immutable
class ManagementAcademicMetric {
  const ManagementAcademicMetric({
    required this.id,
    required this.label,
    required this.value,
    required this.trend,
    required this.accentName,
  });

  final String id;
  final String label;
  final String value;
  final String trend;
  final String accentName;
}

@immutable
class ManagementSubjectPerformance {
  const ManagementSubjectPerformance({
    required this.subject,
    required this.passPercent,
    required this.avgScore,
    required this.atRiskCount,
  });

  final String subject;
  final String passPercent;
  final String avgScore;
  final int atRiskCount;
}

@immutable
class ManagementAcademicHealthData {
  const ManagementAcademicHealthData({
    required this.kpis,
    required this.metrics,
    required this.subjectPerformance,
    required this.atRiskStudents,
    required this.aiInsight,
  });

  final List<ManagementKpi> kpis;
  final List<ManagementAcademicMetric> metrics;
  final List<ManagementSubjectPerformance> subjectPerformance;
  final List<String> atRiskStudents;
  final String aiInsight;
}

@immutable
class ManagementClassPerformanceRow {
  const ManagementClassPerformanceRow({
    required this.classLabel,
    required this.students,
    required this.passPercent,
    required this.avgMarks,
    required this.attendance,
    required this.disciplineScore,
    required this.rank,
  });

  final String classLabel;
  final int students;
  final String passPercent;
  final String avgMarks;
  final String attendance;
  final String disciplineScore;
  final int rank;
}

@immutable
class ManagementPerformanceData {
  const ManagementPerformanceData({
    required this.kpis,
    required this.classPerformance,
    required this.atRiskStudents,
    required this.aiInsight,
  });

  final List<ManagementKpi> kpis;
  final List<ManagementClassPerformanceRow> classPerformance;
  final List<String> atRiskStudents;
  final String aiInsight;
}

@immutable
class ManagementTasksData {
  const ManagementTasksData({
    required this.kpis,
    required this.approvals,
    required this.aiInsight,
  });

  final List<ManagementKpi> kpis;
  final List<ManagementApprovalItem> approvals;
  final String aiInsight;
}

@immutable
class ManagementSettingItem {
  const ManagementSettingItem({
    required this.id,
    required this.label,
    required this.value,
    required this.description,
    required this.editable,
  });

  final String id;
  final String label;
  final String value;
  final String description;
  final bool editable;
}

@immutable
class ManagementSettingsSection {
  const ManagementSettingsSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<ManagementSettingItem> items;
}

@immutable
class ManagementSettingsData {
  const ManagementSettingsData({
    required this.sections,
    required this.academicYear,
  });

  final List<ManagementSettingsSection> sections;
  final String academicYear;
}
