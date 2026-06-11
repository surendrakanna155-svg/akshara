import '../../../../../features/finance/intelligence/finance_intelligence_models.dart';

class FinanceIntelligenceMapper {
  const FinanceIntelligenceMapper();

  FinanceCopilotData toCopilot(Map<String, dynamic> json) {
    return FinanceCopilotData(
      feeCollectionForecast: _int(json['feeCollectionForecast'] ?? json['fee_collection_forecast']),
      forecastConfidence: _int(json['forecastConfidence'] ?? json['forecast_confidence']),
      monthlyRevenueForecast: _int(json['monthlyRevenueForecast'] ?? json['monthly_revenue_forecast']),
      defaulterPredictions: _defaulters(json['defaulterPredictions'] ?? json['defaulter_predictions']),
      collectionTrend: _trend(json['collectionTrend'] ?? json['collection_trend']),
      riskAlerts: _alerts(json['riskAlerts'] ?? json['risk_alerts']),
      generatedAt: json['generatedAt'] as String? ?? json['generated_at'] as String? ?? '',
    );
  }

  FinanceExecutiveData toExecutive(Map<String, dynamic> json) {
    return FinanceExecutiveData(
      expectedCollections: _int(json['expectedCollections'] ?? json['expected_collections']),
      outstandingCollections: _int(json['outstandingCollections'] ?? json['outstanding_collections']),
      collectionHealthScore: _int(json['collectionHealthScore'] ?? json['collection_health_score']),
      riskStudents: _defaulters(json['riskStudents'] ?? json['risk_students']),
      generatedAt: json['generatedAt'] as String? ?? json['generated_at'] as String? ?? '',
    );
  }

  List<FinanceDefaulterPrediction> _defaulters(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return FinanceDefaulterPrediction(
        studentId: m['studentId'] as String? ?? m['student_id'] as String? ?? '',
        studentName: m['studentName'] as String? ?? m['student_name'] as String? ?? '',
        className: m['className'] as String? ?? m['class_name'] as String? ?? '',
        outstandingAmount: _int(m['outstandingAmount'] ?? m['outstanding_amount']),
        riskScore: _int(m['riskScore'] ?? m['risk_score']),
        daysOverdue: _int(m['daysOverdue'] ?? m['days_overdue']),
      );
    }).toList();
  }

  List<FinanceCollectionTrendPoint> _trend(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return FinanceCollectionTrendPoint(
        month: m['month'] as String? ?? '',
        collected: _int(m['collected']),
        expected: _int(m['expected']),
      );
    }).toList();
  }

  List<FinanceCollectionRiskAlert> _alerts(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return FinanceCollectionRiskAlert(
        id: m['id'] as String? ?? '',
        severity: m['severity'] as String? ?? 'low',
        title: m['title'] as String? ?? '',
        detail: m['detail'] as String? ?? '',
      );
    }).toList();
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? 0;
  }
}
