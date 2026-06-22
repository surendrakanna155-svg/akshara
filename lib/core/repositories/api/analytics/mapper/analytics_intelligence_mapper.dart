import '../../../../../features/intelligence/management/intelligence_models.dart';
import '../dto/analytics_intelligence_dto.dart';

class AnalyticsIntelligenceMapper {
  const AnalyticsIntelligenceMapper();

  IntelligenceDashboardMetrics toDashboard(IntelligenceDashboardMetricsDto dto) {
    return IntelligenceDashboardMetrics(
      studentRiskScore: dto.studentRiskScore,
      attendanceRiskScore: dto.attendanceRiskScore,
      academicPerformanceRisk: dto.academicPerformanceRisk,
      feeCollectionRisk: dto.feeCollectionRisk,
      admissionConversionRate: dto.admissionConversionRate,
      teacherWorkloadIndex: dto.teacherWorkloadIndex,
      timetableHealthScore: dto.timetableHealthScore,
      communicationEngagementScore: dto.communicationEngagementScore,
      computedAt: dto.computedAt,
    );
  }

  IntelligenceSchoolHealthSummary toHealth(IntelligenceSchoolHealthSummaryDto dto) {
    return IntelligenceSchoolHealthSummary(
      schoolHealthScore: dto.schoolHealthScore,
      academicHealth: dto.academicHealth,
      financeHealth: dto.financeHealth,
      operationsHealth: dto.operationsHealth,
      engagementHealth: dto.engagementHealth,
      composition: dto.composition.map(toComponent).toList(),
      computedAt: dto.computedAt,
    );
  }

  IntelligenceScoreComponent toComponent(IntelligenceScoreComponentDto dto) {
    return IntelligenceScoreComponent(
      id: dto.id,
      label: dto.label,
      weight: dto.weight,
      score: dto.score,
      detail: dto.detail,
    );
  }

  IntelligenceRiskMetric toRisk(IntelligenceRiskMetricDto dto) {
    return IntelligenceRiskMetric(
      id: dto.id,
      label: dto.label,
      score: dto.score,
      level: riskLevelFromDto(dto.level),
      detail: dto.detail,
    );
  }

  IntelligenceTrendPoint toTrendPoint(IntelligenceTrendPointDto dto) {
    return IntelligenceTrendPoint(
      period: dto.period,
      value: dto.value,
      benchmark: dto.benchmark,
    );
  }

  IntelligenceRecommendation toRecommendation(IntelligenceRecommendationDto dto) {
    return IntelligenceRecommendation(
      kind: dto.kind,
      title: dto.title,
      detail: dto.detail,
    );
  }

  IntelligenceAnomaly toAnomaly(IntelligenceAnomalyDto dto) {
    return IntelligenceAnomaly(
      metric: dto.metric,
      detail: dto.detail,
      severity: riskLevelFromDto(dto.severity),
    );
  }

  IntelligencePrincipalSummary toPrincipalSummary(IntelligencePrincipalSummaryDto dto) {
    return IntelligencePrincipalSummary(
      headline: dto.headline,
      highlights: dto.highlights,
      risks: dto.risks,
      recommendations: dto.recommendations.map(toRecommendation).toList(),
      computedAt: dto.computedAt,
    );
  }

  IntelligenceWeeklyBriefing toWeeklyBriefing(IntelligenceWeeklyBriefingDto dto) {
    return IntelligenceWeeklyBriefing(
      weekLabel: dto.weekLabel,
      sections: dto.sections
          .map(
            (section) => IntelligenceBriefingSection(
              title: section.title,
              bullets: section.bullets,
            ),
          )
          .toList(),
      computedAt: dto.computedAt,
    );
  }
}
