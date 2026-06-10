import 'package:akshara_erp/features/management/intelligence/intelligence_models.dart';

class AnalyticsIntelligenceFixtureBuilder {
  Map<String, dynamic> dashboardEnvelope(IntelligenceDashboardMetrics metrics) {
    return {
      'success': true,
      'data': {
        'studentRiskScore': metrics.studentRiskScore,
        'attendanceRiskScore': metrics.attendanceRiskScore,
        'academicPerformanceRisk': metrics.academicPerformanceRisk,
        'feeCollectionRisk': metrics.feeCollectionRisk,
        'admissionConversionRate': metrics.admissionConversionRate,
        'teacherWorkloadIndex': metrics.teacherWorkloadIndex,
        'timetableHealthScore': metrics.timetableHealthScore,
        'communicationEngagementScore': metrics.communicationEngagementScore,
        'computedAt': metrics.computedAt.toIso8601String(),
      },
    };
  }

  Map<String, dynamic> healthEnvelope(IntelligenceSchoolHealthSummary health) {
    return {
      'success': true,
      'data': {
        'schoolHealthScore': health.schoolHealthScore,
        'academicHealth': health.academicHealth,
        'financeHealth': health.financeHealth,
        'operationsHealth': health.operationsHealth,
        'engagementHealth': health.engagementHealth,
        'composition': [
          for (final component in health.composition)
            {
              'id': component.id,
              'label': component.label,
              'weight': component.weight,
              'score': component.score,
              'detail': component.detail,
            },
        ],
        'computedAt': health.computedAt.toIso8601String(),
      },
    };
  }

  Map<String, dynamic> risksEnvelope(IntelligenceRiskBundle bundle) {
    return {
      'success': true,
      'data': {
        'items': [
          for (final risk in bundle.items)
            {
              'id': risk.id,
              'label': risk.label,
              'score': risk.score,
              'level': risk.level.name,
              'detail': risk.detail,
            },
        ],
        'anomalies': [
          for (final anomaly in bundle.anomalies)
            {
              'metric': anomaly.metric,
              'detail': anomaly.detail,
              'severity': anomaly.severity.name,
            },
        ],
      },
    };
  }
}
