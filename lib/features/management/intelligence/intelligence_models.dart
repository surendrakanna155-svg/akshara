import 'package:flutter/foundation.dart';

enum IntelligenceRiskLevel { low, medium, high }

@immutable
class IntelligenceDashboardMetrics {
  const IntelligenceDashboardMetrics({
    required this.studentRiskScore,
    required this.attendanceRiskScore,
    required this.academicPerformanceRisk,
    required this.feeCollectionRisk,
    required this.admissionConversionRate,
    required this.teacherWorkloadIndex,
    required this.timetableHealthScore,
    required this.communicationEngagementScore,
    required this.computedAt,
  });

  final int studentRiskScore;
  final int attendanceRiskScore;
  final int academicPerformanceRisk;
  final int feeCollectionRisk;
  final int admissionConversionRate;
  final int teacherWorkloadIndex;
  final int timetableHealthScore;
  final int communicationEngagementScore;
  final DateTime computedAt;
}

@immutable
class IntelligenceScoreComponent {
  const IntelligenceScoreComponent({
    required this.id,
    required this.label,
    required this.weight,
    required this.score,
    required this.detail,
  });

  final String id;
  final String label;
  final double weight;
  final int score;
  final String detail;
}

@immutable
class IntelligenceSchoolHealthSummary {
  const IntelligenceSchoolHealthSummary({
    required this.schoolHealthScore,
    required this.academicHealth,
    required this.financeHealth,
    required this.operationsHealth,
    required this.engagementHealth,
    required this.composition,
    required this.computedAt,
  });

  final int schoolHealthScore;
  final int academicHealth;
  final int financeHealth;
  final int operationsHealth;
  final int engagementHealth;
  final List<IntelligenceScoreComponent> composition;
  final DateTime computedAt;
}

@immutable
class IntelligenceRiskMetric {
  const IntelligenceRiskMetric({
    required this.id,
    required this.label,
    required this.score,
    required this.level,
    required this.detail,
  });

  final String id;
  final String label;
  final int score;
  final IntelligenceRiskLevel level;
  final String detail;
}

@immutable
class IntelligenceTrendPoint {
  const IntelligenceTrendPoint({
    required this.period,
    required this.value,
    this.benchmark,
  });

  final String period;
  final int value;
  final int? benchmark;
}

@immutable
class IntelligenceRecommendation {
  const IntelligenceRecommendation({
    required this.kind,
    required this.title,
    required this.detail,
  });

  final String kind;
  final String title;
  final String detail;
}

@immutable
class IntelligenceAnomaly {
  const IntelligenceAnomaly({
    required this.metric,
    required this.detail,
    required this.severity,
  });

  final String metric;
  final String detail;
  final IntelligenceRiskLevel severity;
}

@immutable
class IntelligenceRiskBundle {
  const IntelligenceRiskBundle({
    required this.items,
    required this.anomalies,
  });

  final List<IntelligenceRiskMetric> items;
  final List<IntelligenceAnomaly> anomalies;
}

@immutable
class IntelligenceTrendBundle {
  const IntelligenceTrendBundle({required this.series});

  final Map<String, List<IntelligenceTrendPoint>> series;
}

@immutable
class IntelligencePrincipalSummary {
  const IntelligencePrincipalSummary({
    required this.headline,
    required this.highlights,
    required this.risks,
    required this.recommendations,
    required this.computedAt,
  });

  final String headline;
  final List<String> highlights;
  final List<String> risks;
  final List<IntelligenceRecommendation> recommendations;
  final DateTime computedAt;
}

@immutable
class IntelligenceBriefingSection {
  const IntelligenceBriefingSection({
    required this.title,
    required this.bullets,
  });

  final String title;
  final List<String> bullets;
}

@immutable
class IntelligenceWeeklyBriefing {
  const IntelligenceWeeklyBriefing({
    required this.weekLabel,
    required this.sections,
    required this.computedAt,
  });

  final String weekLabel;
  final List<IntelligenceBriefingSection> sections;
  final DateTime computedAt;
}
