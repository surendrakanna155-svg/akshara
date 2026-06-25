import 'package:flutter/material.dart';

/// Director privacy notice shown across DR screens.
const String kDirectorPrivacyBannerMessage =
    'Aggregated data only · No student PII';

enum DirectorSchoolStatus { topPerformer, onTrack, atRisk, critical }

enum DirectorComplianceStatus { compliant, dueSoon, overdue, notApplicable }

@immutable
class DirectorKpi {
  const DirectorKpi({
    required this.id,
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
  });

  final String id;
  final String label;
  final String value;
  final IconData icon;
  final String? detail;
}

@immutable
class DirectorTrendPoint {
  const DirectorTrendPoint({
    required this.label,
    required this.value,
    this.target,
  });

  final String label;
  final double value;
  final double? target;
}

@immutable
class DirectorSchoolRow {
  const DirectorSchoolRow({
    required this.schoolId,
    required this.schoolName,
    required this.location,
    required this.students,
    required this.revenueCr,
    required this.admissionsQtd,
    required this.feeCollectionPercent,
    required this.healthScore,
    required this.status,
  });

  final String schoolId;
  final String schoolName;
  final String location;
  final int students;
  final double revenueCr;
  final int admissionsQtd;
  final int feeCollectionPercent;
  final int healthScore;
  final DirectorSchoolStatus status;
}

@immutable
class DirectorRevenueSnapshot {
  const DirectorRevenueSnapshot({
    required this.chainRevenueCr,
    required this.expensesCr,
    required this.netCr,
    required this.marginPercent,
    required this.forecastCr,
    required this.revenueBySchool,
    required this.revenueTrend,
  });

  final double chainRevenueCr;
  final double expensesCr;
  final double netCr;
  final int marginPercent;
  final double forecastCr;
  final List<DirectorSchoolRow> revenueBySchool;
  final List<DirectorTrendPoint> revenueTrend;
}

@immutable
class DirectorGrowthSnapshot {
  const DirectorGrowthSnapshot({
    required this.yoyGrowthPercent,
    required this.newEnrollments,
    required this.withdrawals,
    required this.netGrowth,
    required this.capacityPercent,
    required this.enrollmentTrend,
    required this.retentionTrend,
  });

  final int yoyGrowthPercent;
  final int newEnrollments;
  final int withdrawals;
  final int netGrowth;
  final int capacityPercent;
  final List<DirectorTrendPoint> enrollmentTrend;
  final List<DirectorTrendPoint> retentionTrend;
}

@immutable
class DirectorMarketingSnapshot {
  const DirectorMarketingSnapshot({
    required this.totalSpendLakhs,
    required this.totalLeads,
    required this.cplInr,
    required this.roiPercent,
    required this.channelPerformance,
  });

  final double totalSpendLakhs;
  final int totalLeads;
  final int cplInr;
  final int roiPercent;
  final Map<String, double> channelPerformance;
}

@immutable
class DirectorAdmissionsSnapshot {
  const DirectorAdmissionsSnapshot({
    required this.inquiries,
    required this.applications,
    required this.interviews,
    required this.enrolled,
    required this.conversionPercent,
    required this.bySchoolConversion,
  });

  final int inquiries;
  final int applications;
  final int interviews;
  final int enrolled;
  final int conversionPercent;
  final Map<String, int> bySchoolConversion;
}

@immutable
class DirectorComplianceItem {
  const DirectorComplianceItem({
    required this.id,
    required this.schoolName,
    required this.category,
    required this.requirement,
    required this.status,
    required this.dueDate,
    required this.owner,
    required this.evidenceUploaded,
    required this.acknowledged,
  });

  final String id;
  final String schoolName;
  final String category;
  final String requirement;
  final DirectorComplianceStatus status;
  final DateTime dueDate;
  final String owner;
  final bool evidenceUploaded;
  final bool acknowledged;
}

@immutable
class DirectorReportItem {
  const DirectorReportItem({
    required this.id,
    required this.title,
    required this.description,
    required this.lastGeneratedAt,
    required this.fileType,
  });

  final String id;
  final String title;
  final String description;
  final DateTime lastGeneratedAt;
  final String fileType;
}

/// A per-school, per-month figure the chain owner enters because no operational
/// table can produce it (marketing spend, operating expense, capacity). Feeds
/// Revenue (expenses/margin), Marketing (spend/CPL/ROI) and Growth (capacity).
@immutable
class DirectorMetricInput {
  const DirectorMetricInput({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.periodMonth,
    required this.marketingSpendInr,
    required this.operatingExpenseInr,
    required this.studentCapacity,
  });

  final String id;
  final String schoolId;
  final String schoolName;
  final String periodMonth; // YYYY-MM-01
  final double marketingSpendInr;
  final double operatingExpenseInr;
  final int studentCapacity;
}

/// What the metric-input editor submits for an upsert.
@immutable
class DirectorMetricInputDraft {
  const DirectorMetricInputDraft({
    required this.schoolId,
    required this.periodMonth,
    required this.marketingSpendInr,
    required this.operatingExpenseInr,
    required this.studentCapacity,
  });

  final String schoolId;
  final String periodMonth; // YYYY-MM or YYYY-MM-01
  final double marketingSpendInr;
  final double operatingExpenseInr;
  final int studentCapacity;

  Map<String, dynamic> toJson() => {
        'schoolId': schoolId,
        'periodMonth': periodMonth,
        'marketingSpendInr': marketingSpendInr,
        'operatingExpenseInr': operatingExpenseInr,
        'studentCapacity': studentCapacity,
      };
}

@immutable
class DirectorBoardPackKpi {
  const DirectorBoardPackKpi({required this.label, required this.value});

  final String label;
  final String value;
}

/// The real export document: a board-ready pack assembled server-side from live
/// org-wide aggregates. The client renders this into a PDF.
@immutable
class DirectorBoardPack {
  const DirectorBoardPack({
    required this.reportId,
    required this.title,
    required this.description,
    required this.fileType,
    required this.generatedAt,
    required this.executiveSummary,
    required this.kpis,
    required this.schools,
    required this.chainRevenueCr,
    required this.expensesCr,
    required this.netCr,
    required this.marginPercent,
    required this.forecastCr,
    required this.yoyGrowthPercent,
    required this.netGrowth,
    required this.capacityPercent,
    required this.inquiries,
    required this.enrolled,
    required this.conversionPercent,
    required this.totalSpendLakhs,
    required this.totalLeads,
    required this.roiPercent,
    required this.complianceTotal,
    required this.complianceOverdue,
  });

  final String reportId;
  final String title;
  final String description;
  final String fileType;
  final DateTime generatedAt;
  final String executiveSummary;
  final List<DirectorBoardPackKpi> kpis;
  final List<DirectorSchoolRow> schools;
  final double chainRevenueCr;
  final double expensesCr;
  final double netCr;
  final int marginPercent;
  final double forecastCr;
  final int yoyGrowthPercent;
  final int netGrowth;
  final int capacityPercent;
  final int inquiries;
  final int enrolled;
  final int conversionPercent;
  final double totalSpendLakhs;
  final int totalLeads;
  final int roiPercent;
  final int complianceTotal;
  final int complianceOverdue;
}

@immutable
class DirectorDashboardData {
  const DirectorDashboardData({
    required this.kpis,
    required this.schoolRows,
    required this.revenue,
    required this.growth,
    required this.marketing,
    required this.admissions,
    required this.complianceAlerts,
    required this.executiveSummary,
  });

  final List<DirectorKpi> kpis;
  final List<DirectorSchoolRow> schoolRows;
  final DirectorRevenueSnapshot revenue;
  final DirectorGrowthSnapshot growth;
  final DirectorMarketingSnapshot marketing;
  final DirectorAdmissionsSnapshot admissions;
  final List<DirectorComplianceItem> complianceAlerts;
  final String executiveSummary;
}
