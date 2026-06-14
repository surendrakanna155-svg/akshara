import '../../../features/control_center/intelligence/platform_intelligence_models.dart';
import '../interfaces/platform_intelligence_repository.dart';
import '../repository_query.dart';

class MockPlatformIntelligenceRepository
    implements PlatformIntelligenceRepository {
  static const _ownerKpis = [
    PlatformIntelligenceKpi(
      id: 'portfolio_revenue',
      label: 'Portfolio Revenue',
      value: 'INR 786.4L',
      delta: '+11.8% YoY',
    ),
    PlatformIntelligenceKpi(
      id: 'active_schools',
      label: 'Active Schools',
      value: '48',
      delta: '+4 this quarter',
    ),
    PlatformIntelligenceKpi(
      id: 'collection_efficiency',
      label: 'Collection Efficiency',
      value: '96.2%',
      delta: '+2.1 pts',
    ),
    PlatformIntelligenceKpi(
      id: 'portfolio_risk',
      label: 'Portfolio Risk',
      value: '18',
      delta: '-4 points',
    ),
  ];

  @override
  Future<PlatformIntelligenceDashboard> getPlatformIntelligenceDashboard({
    required RepositoryQuery query,
  }) async {
    return const PlatformIntelligenceDashboard(
      ownerKpis: _ownerKpis,
      organizationKpis: [
        PlatformIntelligenceKpi(
          id: 'org_count',
          label: 'Organizations',
          value: '6',
          delta: '+1 this year',
        ),
        PlatformIntelligenceKpi(
          id: 'trusts_healthy',
          label: 'Healthy Trusts',
          value: '5/6',
          delta: '1 requires intervention',
        ),
      ],
      topInsights: [
        PlatformInsightItem(
          title: 'North cluster outperforms portfolio',
          detail:
              'North region schools are growing 14% YoY versus portfolio 9.7%.',
          priority: 'high',
        ),
        PlatformInsightItem(
          title: 'Collections lagging in two campuses',
          detail:
              'Heritage Convent Pune and Green Valley Mumbai are below 86% monthly collection.',
          priority: 'high',
        ),
        PlatformInsightItem(
          title: 'Premium migration opportunity',
          detail:
              '3 standard-plan schools have usage depth above enterprise threshold for 3 months.',
          priority: 'medium',
        ),
      ],
    );
  }

  @override
  Future<OrganizationIntelligence> getOrganizationIntelligence({
    required RepositoryQuery query,
    required String orgId,
  }) async {
    return OrganizationIntelligence(
      organizationId: orgId,
      organizationName: 'Akshara Education Trust',
      schoolCount: 11,
      activeStudentCount: 28940,
      revenueLakhs: 214.6,
      collectionEfficiencyPercent: 97,
      healthScore: 89,
      recommendations: const [
        'Prioritize parent reminder automation for South-2 schools.',
        'Expand premium analytics to 4 high-usage standard campuses.',
        'Complete transport SLA remediation in Pune cluster.',
      ],
    );
  }

  @override
  Future<SchoolComparisonIntelligence> compareSchools({
    required RepositoryQuery query,
    required List<String> schoolIds,
  }) async {
    const rows = [
      SchoolComparisonRow(
        schoolId: 'SCH-1001',
        schoolName: 'Akshara International Hyderabad',
        studentCount: 2840,
        revenueLakhs: 52.4,
        growthPercent: 13,
        riskScore: 14,
      ),
      SchoolComparisonRow(
        schoolId: 'SCH-1003',
        schoolName: 'Sunrise Academy Bengaluru',
        studentCount: 4200,
        revenueLakhs: 86.8,
        growthPercent: 16,
        riskScore: 11,
      ),
      SchoolComparisonRow(
        schoolId: 'SCH-1004',
        schoolName: 'Heritage Convent Pune',
        studentCount: 890,
        revenueLakhs: 12.9,
        growthPercent: 4,
        riskScore: 36,
      ),
      SchoolComparisonRow(
        schoolId: 'SCH-1005',
        schoolName: 'DPS Noida',
        studentCount: 3100,
        revenueLakhs: 61.2,
        growthPercent: 10,
        riskScore: 19,
      ),
    ];
    final selected = schoolIds.isEmpty
        ? rows
        : rows.where((row) => schoolIds.contains(row.schoolId)).toList();
    return SchoolComparisonIntelligence(
      rows: selected,
      benchmarks: const [
        PlatformInsightItem(
          title: 'Best growth momentum',
          detail:
              'Sunrise Academy Bengaluru leads with 16% growth and low risk score.',
          priority: 'high',
        ),
        PlatformInsightItem(
          title: 'Immediate churn watch',
          detail:
              'Heritage Convent Pune shows low growth and high payment risk.',
          priority: 'high',
        ),
      ],
    );
  }

  @override
  Future<RevenueIntelligence> getRevenueIntelligence({
    required RepositoryQuery query,
  }) async {
    return const RevenueIntelligence(
      kpis: [
        PlatformIntelligenceKpi(
          id: 'mrr',
          label: 'MRR',
          value: 'INR 65.8L',
          delta: '+8.2% MoM',
        ),
        PlatformIntelligenceKpi(
          id: 'arr',
          label: 'ARR',
          value: 'INR 7.9Cr',
          delta: '+12.4% YoY',
        ),
        PlatformIntelligenceKpi(
          id: 'outstanding',
          label: 'Outstanding',
          value: 'INR 22.6L',
          delta: '-6.0% MoM',
        ),
      ],
      revenueTrend: [
        PlatformTrendPoint(label: 'Jan', value: 58.4, target: 59.0),
        PlatformTrendPoint(label: 'Feb', value: 59.6, target: 60.0),
        PlatformTrendPoint(label: 'Mar', value: 61.1, target: 61.0),
        PlatformTrendPoint(label: 'Apr', value: 62.7, target: 62.0),
        PlatformTrendPoint(label: 'May', value: 64.1, target: 63.0),
        PlatformTrendPoint(label: 'Jun', value: 65.8, target: 64.0),
      ],
      organizationBreakdown: [
        PlatformIntelligenceKpi(
          id: 'org_akshara',
          label: 'Akshara Trust',
          value: 'INR 22.4L',
          delta: '34%',
        ),
        PlatformIntelligenceKpi(
          id: 'org_sarvodaya',
          label: 'Sarvodaya Group',
          value: 'INR 16.2L',
          delta: '25%',
        ),
        PlatformIntelligenceKpi(
          id: 'org_northstar',
          label: 'Northstar Education',
          value: 'INR 12.7L',
          delta: '19%',
        ),
      ],
    );
  }

  @override
  Future<GrowthIntelligence> getGrowthIntelligence({
    required RepositoryQuery query,
  }) async {
    return const GrowthIntelligence(
      kpis: [
        PlatformIntelligenceKpi(
          id: 'pipeline_value',
          label: 'Pipeline Value',
          value: 'INR 148L',
          delta: '+18% QoQ',
        ),
        PlatformIntelligenceKpi(
          id: 'upsell_ready',
          label: 'Upsell Ready Schools',
          value: '9',
          delta: '3 in final stage',
        ),
      ],
      pipeline: [
        GrowthInitiative(
          name: 'East Region Expansion',
          stage: 'Negotiation',
          expectedRevenueLakhs: 34.0,
          timeline: 'Q3 FY27',
        ),
        GrowthInitiative(
          name: 'Premium Upgrade Wave',
          stage: 'Proposal',
          expectedRevenueLakhs: 21.5,
          timeline: 'Q2 FY27',
        ),
        GrowthInitiative(
          name: 'AI Analytics Add-on',
          stage: 'Pilot',
          expectedRevenueLakhs: 12.0,
          timeline: 'Q4 FY27',
        ),
      ],
      expansionSignals: [
        PlatformInsightItem(
          title: 'Admissions-led expansion',
          detail:
              'Four schools crossed 90% admissions workflow automation adoption.',
          priority: 'medium',
        ),
        PlatformInsightItem(
          title: 'Cross-sell opportunity',
          detail:
              'Transport + Hostel bundle has 62% conversion in pilot cohorts.',
          priority: 'high',
        ),
      ],
    );
  }

  @override
  Future<PortfolioRiskIntelligence> getPortfolioRiskIntelligence({
    required RepositoryQuery query,
  }) async {
    return const PortfolioRiskIntelligence(
      kpis: [
        PlatformIntelligenceKpi(
          id: 'avg_risk',
          label: 'Average Portfolio Risk',
          value: '18',
          delta: '-4 QoQ',
        ),
        PlatformIntelligenceKpi(
          id: 'high_risk_schools',
          label: 'High Risk Schools',
          value: '3',
          delta: '-1 this month',
        ),
      ],
      riskTrend: [
        PlatformTrendPoint(label: 'Jan', value: 24),
        PlatformTrendPoint(label: 'Feb', value: 23),
        PlatformTrendPoint(label: 'Mar', value: 22),
        PlatformTrendPoint(label: 'Apr', value: 20),
        PlatformTrendPoint(label: 'May', value: 19),
        PlatformTrendPoint(label: 'Jun', value: 18),
      ],
      risks: [
        PortfolioRiskItem(
          schoolId: 'SCH-1004',
          schoolName: 'Heritage Convent Pune',
          riskType: 'Collection default',
          riskScore: 36,
          mitigation:
              'Assign CS + finance audit; weekly closure tracker for 30 days.',
        ),
        PortfolioRiskItem(
          schoolId: 'SCH-1002',
          schoolName: 'Green Valley Mumbai',
          riskType: 'Product adoption decline',
          riskScore: 29,
          mitigation:
              'Activate usage recovery plan for SIS + HR within current term.',
        ),
        PortfolioRiskItem(
          schoolId: 'SCH-1022',
          schoolName: 'Lotus Valley Jaipur',
          riskType: 'Onboarding delay',
          riskScore: 27,
          mitigation:
              'Deployment war-room and migration support for academic workflows.',
        ),
      ],
    );
  }
}
