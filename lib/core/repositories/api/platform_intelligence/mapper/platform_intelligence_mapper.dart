import '../../../../../features/control_center/intelligence/platform_intelligence_models.dart';

class PlatformIntelligenceMapper {
  const PlatformIntelligenceMapper();

  PlatformIntelligenceDashboard toDashboard(Map<String, dynamic> raw) {
    return PlatformIntelligenceDashboard(
      ownerKpis: _kpis(raw['ownerKpis']),
      organizationKpis: _kpis(raw['organizationKpis']),
      topInsights: _insights(raw['topInsights']),
    );
  }

  OrganizationIntelligence toOrganization(Map<String, dynamic> raw) {
    return OrganizationIntelligence(
      organizationId: raw['organizationId'] as String? ?? '',
      organizationName: raw['organizationName'] as String? ?? '',
      schoolCount: raw['schoolCount'] as int? ?? 0,
      activeStudentCount: raw['activeStudentCount'] as int? ?? 0,
      revenueLakhs: (raw['revenueLakhs'] as num?)?.toDouble() ?? 0,
      collectionEfficiencyPercent:
          raw['collectionEfficiencyPercent'] as int? ?? 0,
      healthScore: raw['healthScore'] as int? ?? 0,
      recommendations: [
        for (final value in (raw['recommendations'] as List? ?? const []))
          value.toString(),
      ],
    );
  }

  SchoolComparisonIntelligence toComparison(Map<String, dynamic> raw) {
    final rows = (raw['rows'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => SchoolComparisonRow(
            schoolId: item['schoolId'] as String? ?? '',
            schoolName: item['schoolName'] as String? ?? '',
            studentCount: item['studentCount'] as int? ?? 0,
            revenueLakhs: (item['revenueLakhs'] as num?)?.toDouble() ?? 0,
            growthPercent: item['growthPercent'] as int? ?? 0,
            riskScore: item['riskScore'] as int? ?? 0,
          ),
        )
        .toList();

    return SchoolComparisonIntelligence(
      rows: rows,
      benchmarks: _insights(raw['benchmarks']),
    );
  }

  RevenueIntelligence toRevenue(Map<String, dynamic> raw) {
    return RevenueIntelligence(
      kpis: _kpis(raw['kpis']),
      revenueTrend: _trend(raw['revenueTrend']),
      organizationBreakdown: _kpis(raw['organizationBreakdown']),
    );
  }

  GrowthIntelligence toGrowth(Map<String, dynamic> raw) {
    final pipeline = (raw['pipeline'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => GrowthInitiative(
            name: item['name'] as String? ?? '',
            stage: item['stage'] as String? ?? '',
            expectedRevenueLakhs:
                (item['expectedRevenueLakhs'] as num?)?.toDouble() ?? 0,
            timeline: item['timeline'] as String? ?? '',
          ),
        )
        .toList();

    return GrowthIntelligence(
      kpis: _kpis(raw['kpis']),
      pipeline: pipeline,
      expansionSignals: _insights(raw['expansionSignals']),
    );
  }

  PortfolioRiskIntelligence toRisk(Map<String, dynamic> raw) {
    final risks = (raw['risks'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => PortfolioRiskItem(
            schoolId: item['schoolId'] as String? ?? '',
            schoolName: item['schoolName'] as String? ?? '',
            riskType: item['riskType'] as String? ?? '',
            riskScore: item['riskScore'] as int? ?? 0,
            mitigation: item['mitigation'] as String? ?? '',
          ),
        )
        .toList();

    return PortfolioRiskIntelligence(
      kpis: _kpis(raw['kpis']),
      riskTrend: _trend(raw['riskTrend']),
      risks: risks,
    );
  }

  TrustDashboardIntelligence toTrustDashboard(Map<String, dynamic> raw) {
    return TrustDashboardIntelligence(
      trustName: raw['trustName'] as String? ?? '',
      kpis: _kpis(raw['kpis']),
      trend: _trend(raw['trend']),
      riskHighlights: _insights(raw['riskHighlights']),
    );
  }

  ExecutiveSummaryIntelligence toExecutiveSummary(Map<String, dynamic> raw) {
    return ExecutiveSummaryIntelligence(
      headline: raw['headline'] as String? ?? '',
      summary: raw['summary'] as String? ?? '',
      priorityActions: _insights(raw['priorityActions']),
    );
  }

  List<PlatformIntelligenceKpi> _kpis(Object? value) {
    return (value as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => PlatformIntelligenceKpi(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            value: item['value'] as String? ?? '',
            delta: item['delta'] as String?,
          ),
        )
        .toList();
  }

  List<PlatformInsightItem> _insights(Object? value) {
    return (value as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => PlatformInsightItem(
            title: item['title'] as String? ?? '',
            detail: item['detail'] as String? ?? '',
            priority: item['priority'] as String? ?? 'medium',
          ),
        )
        .toList();
  }

  List<PlatformTrendPoint> _trend(Object? value) {
    return (value as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => PlatformTrendPoint(
            label: item['label'] as String? ?? '',
            value: (item['value'] as num?)?.toDouble() ?? 0,
            target: (item['target'] as num?)?.toDouble(),
          ),
        )
        .toList();
  }
}
