import '../../../../../features/management/intelligence/intelligence_models.dart';

Map<String, dynamic> parseAnalyticsEnvelope(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map<String, dynamic>) return data;
  throw const FormatException('Invalid analytics envelope: missing data');
}

List<dynamic> parseAnalyticsItems(Map<String, dynamic> json) {
  final data = parseAnalyticsEnvelope(json);
  final items = data['items'];
  if (items is List<dynamic>) return items;
  return const [];
}

IntelligenceRiskLevel riskLevelFromDto(String? value) => switch (value) {
      'high' => IntelligenceRiskLevel.high,
      'medium' => IntelligenceRiskLevel.medium,
      _ => IntelligenceRiskLevel.low,
    };

class IntelligenceDashboardMetricsDto {
  IntelligenceDashboardMetricsDto({
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

  factory IntelligenceDashboardMetricsDto.fromJson(Map<String, dynamic> json) {
    return IntelligenceDashboardMetricsDto(
      studentRiskScore: _asInt(json['student_risk_score'] ?? json['studentRiskScore']),
      attendanceRiskScore: _asInt(json['attendance_risk_score'] ?? json['attendanceRiskScore']),
      academicPerformanceRisk:
          _asInt(json['academic_performance_risk'] ?? json['academicPerformanceRisk']),
      feeCollectionRisk: _asInt(json['fee_collection_risk'] ?? json['feeCollectionRisk']),
      admissionConversionRate:
          _asInt(json['admission_conversion_rate'] ?? json['admissionConversionRate']),
      teacherWorkloadIndex: _asInt(json['teacher_workload_index'] ?? json['teacherWorkloadIndex']),
      timetableHealthScore: _asInt(json['timetable_health_score'] ?? json['timetableHealthScore']),
      communicationEngagementScore: _asInt(
        json['communication_engagement_score'] ?? json['communicationEngagementScore'],
      ),
      computedAt: DateTime.tryParse(json['computed_at'] as String? ?? json['computedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

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

class IntelligenceScoreComponentDto {
  IntelligenceScoreComponentDto({
    required this.id,
    required this.label,
    required this.weight,
    required this.score,
    required this.detail,
  });

  factory IntelligenceScoreComponentDto.fromJson(Map<String, dynamic> json) {
    return IntelligenceScoreComponentDto(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      score: _asInt(json['score']),
      detail: json['detail'] as String? ?? '',
    );
  }

  final String id;
  final String label;
  final double weight;
  final int score;
  final String detail;
}

class IntelligenceSchoolHealthSummaryDto {
  IntelligenceSchoolHealthSummaryDto({
    required this.schoolHealthScore,
    required this.academicHealth,
    required this.financeHealth,
    required this.operationsHealth,
    required this.engagementHealth,
    required this.composition,
    required this.computedAt,
  });

  factory IntelligenceSchoolHealthSummaryDto.fromJson(Map<String, dynamic> json) {
    final rawComposition = json['composition'] as List<dynamic>? ?? const [];
    return IntelligenceSchoolHealthSummaryDto(
      schoolHealthScore: _asInt(json['school_health_score'] ?? json['schoolHealthScore']),
      academicHealth: _asInt(json['academic_health'] ?? json['academicHealth']),
      financeHealth: _asInt(json['finance_health'] ?? json['financeHealth']),
      operationsHealth: _asInt(json['operations_health'] ?? json['operationsHealth']),
      engagementHealth: _asInt(json['engagement_health'] ?? json['engagementHealth']),
      composition: rawComposition
          .map((item) => IntelligenceScoreComponentDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      computedAt: DateTime.tryParse(json['computed_at'] as String? ?? json['computedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final int schoolHealthScore;
  final int academicHealth;
  final int financeHealth;
  final int operationsHealth;
  final int engagementHealth;
  final List<IntelligenceScoreComponentDto> composition;
  final DateTime computedAt;
}

class IntelligenceRiskMetricDto {
  IntelligenceRiskMetricDto({
    required this.id,
    required this.label,
    required this.score,
    required this.level,
    required this.detail,
  });

  factory IntelligenceRiskMetricDto.fromJson(Map<String, dynamic> json) {
    return IntelligenceRiskMetricDto(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      score: _asInt(json['score']),
      level: json['level'] as String? ?? 'low',
      detail: json['detail'] as String? ?? '',
    );
  }

  final String id;
  final String label;
  final int score;
  final String level;
  final String detail;
}

class IntelligenceTrendPointDto {
  IntelligenceTrendPointDto({
    required this.period,
    required this.value,
    this.benchmark,
  });

  factory IntelligenceTrendPointDto.fromJson(Map<String, dynamic> json) {
    return IntelligenceTrendPointDto(
      period: json['period'] as String? ?? '',
      value: _asInt(json['value']),
      benchmark: json['benchmark'] == null ? null : _asInt(json['benchmark']),
    );
  }

  final String period;
  final int value;
  final int? benchmark;
}

class IntelligenceRecommendationDto {
  IntelligenceRecommendationDto({
    required this.kind,
    required this.title,
    required this.detail,
  });

  factory IntelligenceRecommendationDto.fromJson(Map<String, dynamic> json) {
    return IntelligenceRecommendationDto(
      kind: json['kind'] as String? ?? '',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }

  final String kind;
  final String title;
  final String detail;
}

class IntelligenceAnomalyDto {
  IntelligenceAnomalyDto({
    required this.metric,
    required this.detail,
    required this.severity,
  });

  factory IntelligenceAnomalyDto.fromJson(Map<String, dynamic> json) {
    return IntelligenceAnomalyDto(
      metric: json['metric'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      severity: json['severity'] as String? ?? 'low',
    );
  }

  final String metric;
  final String detail;
  final String severity;
}

class IntelligencePrincipalSummaryDto {
  IntelligencePrincipalSummaryDto({
    required this.headline,
    required this.highlights,
    required this.risks,
    required this.recommendations,
    required this.computedAt,
  });

  factory IntelligencePrincipalSummaryDto.fromJson(Map<String, dynamic> json) {
    return IntelligencePrincipalSummaryDto(
      headline: json['headline'] as String? ?? '',
      highlights: (json['highlights'] as List<dynamic>? ?? const []).cast<String>(),
      risks: (json['risks'] as List<dynamic>? ?? const []).cast<String>(),
      recommendations: (json['recommendations'] as List<dynamic>? ?? const [])
          .map((item) => IntelligenceRecommendationDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      computedAt: DateTime.tryParse(json['computed_at'] as String? ?? json['computedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final String headline;
  final List<String> highlights;
  final List<String> risks;
  final List<IntelligenceRecommendationDto> recommendations;
  final DateTime computedAt;
}

class IntelligenceWeeklyBriefingDto {
  IntelligenceWeeklyBriefingDto({
    required this.weekLabel,
    required this.sections,
    required this.computedAt,
  });

  factory IntelligenceWeeklyBriefingDto.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    return IntelligenceWeeklyBriefingDto(
      weekLabel: json['week_label'] as String? ?? json['weekLabel'] as String? ?? '',
      sections: rawSections.map((section) {
        final map = section as Map<String, dynamic>;
        return IntelligenceBriefingSectionDto(
          title: map['title'] as String? ?? '',
          bullets: (map['bullets'] as List<dynamic>? ?? const []).cast<String>(),
        );
      }).toList(),
      computedAt: DateTime.tryParse(json['computed_at'] as String? ?? json['computedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final String weekLabel;
  final List<IntelligenceBriefingSectionDto> sections;
  final DateTime computedAt;
}

class IntelligenceBriefingSectionDto {
  IntelligenceBriefingSectionDto({
    required this.title,
    required this.bullets,
  });

  final String title;
  final List<String> bullets;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
