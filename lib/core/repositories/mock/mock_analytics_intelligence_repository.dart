import '../../../features/management/intelligence/intelligence_models.dart';
import '../interfaces/analytics_intelligence_repository.dart';
import '../repository_query.dart';

class MockAnalyticsIntelligenceRepository implements AnalyticsIntelligenceRepository {
  MockAnalyticsIntelligenceRepository() {
    final computedAt = DateTime.utc(2026, 6, 10, 12);
    _dashboard = IntelligenceDashboardMetrics(
      studentRiskScore: 15,
      attendanceRiskScore: 12,
      academicPerformanceRisk: 18,
      feeCollectionRisk: 16,
      admissionConversionRate: 40,
      teacherWorkloadIndex: 13,
      timetableHealthScore: 80,
      communicationEngagementScore: 95,
      computedAt: computedAt,
    );
    _health = IntelligenceSchoolHealthSummary(
      schoolHealthScore: 80,
      academicHealth: 84,
      financeHealth: 84,
      operationsHealth: 83,
      engagementHealth: 68,
      composition: const [
        IntelligenceScoreComponent(
          id: 'academic',
          label: 'Academic Health',
          weight: 0.25,
          score: 84,
          detail: 'Derived from student risk and academic performance risk (inverted).',
        ),
        IntelligenceScoreComponent(
          id: 'finance',
          label: 'Finance Health',
          weight: 0.25,
          score: 84,
          detail: 'Derived from fee collection risk (inverted).',
        ),
        IntelligenceScoreComponent(
          id: 'operations',
          label: 'Operations Health',
          weight: 0.25,
          score: 83,
          detail: 'Blend of timetable health and normalized teacher workload.',
        ),
        IntelligenceScoreComponent(
          id: 'engagement',
          label: 'Engagement Health',
          weight: 0.25,
          score: 68,
          detail: 'Blend of communication delivery success and admissions conversion.',
        ),
      ],
      computedAt: computedAt,
    );
    _risks = const IntelligenceRiskBundle(
      items: [
        IntelligenceRiskMetric(
          id: 'student',
          label: 'Student Risk',
          score: 15,
          level: IntelligenceRiskLevel.low,
          detail: 'Composite of attendance, academic, and fee risk signals.',
        ),
        IntelligenceRiskMetric(
          id: 'attendance',
          label: 'Attendance Risk',
          score: 12,
          level: IntelligenceRiskLevel.low,
          detail: 'Based on absent rate across recorded attendance sessions.',
        ),
        IntelligenceRiskMetric(
          id: 'academic',
          label: 'Academic Performance Risk',
          score: 18,
          level: IntelligenceRiskLevel.low,
          detail: 'Based on share of exam marks below 40% of maximum.',
        ),
        IntelligenceRiskMetric(
          id: 'fee',
          label: 'Fee Collection Risk',
          score: 16,
          level: IntelligenceRiskLevel.low,
          detail: 'Based on open invoices relative to enrolled students.',
        ),
      ],
      anomalies: [],
    );
    _trends = const IntelligenceTrendBundle(
      series: {
        'schoolHealth': [
          IntelligenceTrendPoint(period: 'W-4', value: 74, benchmark: 80),
          IntelligenceTrendPoint(period: 'W-3', value: 76, benchmark: 80),
          IntelligenceTrendPoint(period: 'W-2', value: 78, benchmark: 80),
          IntelligenceTrendPoint(period: 'W-1', value: 79, benchmark: 80),
          IntelligenceTrendPoint(period: 'Now', value: 80, benchmark: 80),
        ],
        'studentRisk': [
          IntelligenceTrendPoint(period: 'W-4', value: 23),
          IntelligenceTrendPoint(period: 'W-3', value: 20),
          IntelligenceTrendPoint(period: 'W-2', value: 18),
          IntelligenceTrendPoint(period: 'W-1', value: 16),
          IntelligenceTrendPoint(period: 'Now', value: 15),
        ],
        'feeCollection': [
          IntelligenceTrendPoint(period: 'W-4', value: 79),
          IntelligenceTrendPoint(period: 'W-3', value: 81),
          IntelligenceTrendPoint(period: 'W-2', value: 82),
          IntelligenceTrendPoint(period: 'W-1', value: 83),
          IntelligenceTrendPoint(period: 'Now', value: 84),
        ],
      },
    );
    _recommendations = const [
      IntelligenceRecommendation(
        kind: 'engagement',
        title: 'Improve admissions conversion follow-up',
        detail: 'Conversion rate is below target; review counselor follow-up cadence (read-only).',
      ),
      IntelligenceRecommendation(
        kind: 'operations',
        title: 'Resolve timetable conflicts before publish',
        detail: 'Two timetable conflicts remain in draft schedules (read-only).',
      ),
    ];
    _principalSummary = IntelligencePrincipalSummary(
      headline: 'School health is stable with engagement as the primary improvement area.',
      highlights: const [
        'School health score at 80 with balanced academic and finance pillars.',
        'Communication delivery success above 90%.',
        'Timetable health remains strong with manageable workload signals.',
      ],
      risks: const [
        'Admissions conversion below 50% target.',
        'Fee collection risk remains non-zero with open invoices.',
      ],
      recommendations: _recommendations,
      computedAt: computedAt,
    );
    _weeklyBriefing = IntelligenceWeeklyBriefing(
      weekLabel: 'Week of 10 Jun 2026',
      sections: const [
        IntelligenceBriefingSection(
          title: 'Academic',
          bullets: [
            'Student risk score remains low at 15.',
            'Academic performance risk stable week-over-week.',
          ],
        ),
        IntelligenceBriefingSection(
          title: 'Finance',
          bullets: [
            'Fee collection health at 84 with 16 risk points from open invoices.',
          ],
        ),
        IntelligenceBriefingSection(
          title: 'Operations',
          bullets: [
            'Timetable health at 80; monitor overloaded teachers.',
          ],
        ),
      ],
      computedAt: computedAt,
    );
  }

  late final IntelligenceDashboardMetrics _dashboard;
  late final IntelligenceSchoolHealthSummary _health;
  late final IntelligenceRiskBundle _risks;
  late final IntelligenceTrendBundle _trends;
  late final List<IntelligenceRecommendation> _recommendations;
  late final IntelligencePrincipalSummary _principalSummary;
  late final IntelligenceWeeklyBriefing _weeklyBriefing;

  @override
  Future<IntelligenceDashboardMetrics> getDashboardMetrics({
    required RepositoryQuery query,
  }) async =>
      _dashboard;

  @override
  Future<IntelligenceTrendBundle> getTrends({
    required RepositoryQuery query,
  }) async =>
      _trends;

  @override
  Future<IntelligenceRiskBundle> getRisks({
    required RepositoryQuery query,
  }) async =>
      _risks;

  @override
  Future<IntelligenceSchoolHealthSummary> getSchoolHealth({
    required RepositoryQuery query,
  }) async =>
      _health;

  @override
  Future<List<IntelligenceRecommendation>> getRecommendations({
    required RepositoryQuery query,
  }) async =>
      _recommendations;

  @override
  Future<IntelligencePrincipalSummary> getPrincipalSummary({
    required RepositoryQuery query,
  }) async =>
      _principalSummary;

  @override
  Future<IntelligenceWeeklyBriefing> getWeeklyBriefing({
    required RepositoryQuery query,
  }) async =>
      _weeklyBriefing;
}
