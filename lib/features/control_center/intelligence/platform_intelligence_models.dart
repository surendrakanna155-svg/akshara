import 'package:flutter/foundation.dart';

@immutable
class PlatformIntelligenceKpi {
  const PlatformIntelligenceKpi({
    required this.id,
    required this.label,
    required this.value,
    this.delta,
  });

  final String id;
  final String label;
  final String value;
  final String? delta;
}

@immutable
class PlatformTrendPoint {
  const PlatformTrendPoint({
    required this.label,
    required this.value,
    this.target,
  });

  final String label;
  final double value;
  final double? target;
}

@immutable
class PlatformInsightItem {
  const PlatformInsightItem({
    required this.title,
    required this.detail,
    required this.priority,
  });

  final String title;
  final String detail;
  final String priority;
}

@immutable
class PlatformIntelligenceDashboard {
  const PlatformIntelligenceDashboard({
    required this.ownerKpis,
    required this.organizationKpis,
    required this.topInsights,
  });

  final List<PlatformIntelligenceKpi> ownerKpis;
  final List<PlatformIntelligenceKpi> organizationKpis;
  final List<PlatformInsightItem> topInsights;
}

@immutable
class OrganizationIntelligence {
  const OrganizationIntelligence({
    required this.organizationId,
    required this.organizationName,
    required this.schoolCount,
    required this.activeStudentCount,
    required this.revenueLakhs,
    required this.collectionEfficiencyPercent,
    required this.healthScore,
    required this.recommendations,
  });

  final String organizationId;
  final String organizationName;
  final int schoolCount;
  final int activeStudentCount;
  final double revenueLakhs;
  final int collectionEfficiencyPercent;
  final int healthScore;
  final List<String> recommendations;
}

@immutable
class SchoolComparisonRow {
  const SchoolComparisonRow({
    required this.schoolId,
    required this.schoolName,
    required this.studentCount,
    required this.revenueLakhs,
    required this.growthPercent,
    required this.riskScore,
  });

  final String schoolId;
  final String schoolName;
  final int studentCount;
  final double revenueLakhs;
  final int growthPercent;
  final int riskScore;
}

@immutable
class SchoolComparisonIntelligence {
  const SchoolComparisonIntelligence({
    required this.rows,
    required this.benchmarks,
  });

  final List<SchoolComparisonRow> rows;
  final List<PlatformInsightItem> benchmarks;
}

@immutable
class RevenueIntelligence {
  const RevenueIntelligence({
    required this.kpis,
    required this.revenueTrend,
    required this.organizationBreakdown,
  });

  final List<PlatformIntelligenceKpi> kpis;
  final List<PlatformTrendPoint> revenueTrend;
  final List<PlatformIntelligenceKpi> organizationBreakdown;
}

@immutable
class GrowthInitiative {
  const GrowthInitiative({
    required this.name,
    required this.stage,
    required this.expectedRevenueLakhs,
    required this.timeline,
  });

  final String name;
  final String stage;
  final double expectedRevenueLakhs;
  final String timeline;
}

@immutable
class GrowthIntelligence {
  const GrowthIntelligence({
    required this.kpis,
    required this.pipeline,
    required this.expansionSignals,
  });

  final List<PlatformIntelligenceKpi> kpis;
  final List<GrowthInitiative> pipeline;
  final List<PlatformInsightItem> expansionSignals;
}

@immutable
class PortfolioRiskItem {
  const PortfolioRiskItem({
    required this.schoolId,
    required this.schoolName,
    required this.riskType,
    required this.riskScore,
    required this.mitigation,
  });

  final String schoolId;
  final String schoolName;
  final String riskType;
  final int riskScore;
  final String mitigation;
}

@immutable
class PortfolioRiskIntelligence {
  const PortfolioRiskIntelligence({
    required this.kpis,
    required this.riskTrend,
    required this.risks,
  });

  final List<PlatformIntelligenceKpi> kpis;
  final List<PlatformTrendPoint> riskTrend;
  final List<PortfolioRiskItem> risks;
}
