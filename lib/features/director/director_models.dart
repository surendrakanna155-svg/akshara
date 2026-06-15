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
