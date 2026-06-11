import 'package:flutter/foundation.dart';

@immutable
class FinanceCopilotData {
  const FinanceCopilotData({
    required this.feeCollectionForecast,
    required this.forecastConfidence,
    required this.monthlyRevenueForecast,
    required this.defaulterPredictions,
    required this.collectionTrend,
    required this.riskAlerts,
    required this.generatedAt,
  });

  final int feeCollectionForecast;
  final int forecastConfidence;
  final int monthlyRevenueForecast;
  final List<FinanceDefaulterPrediction> defaulterPredictions;
  final List<FinanceCollectionTrendPoint> collectionTrend;
  final List<FinanceCollectionRiskAlert> riskAlerts;
  final String generatedAt;
}

@immutable
class FinanceExecutiveData {
  const FinanceExecutiveData({
    required this.expectedCollections,
    required this.outstandingCollections,
    required this.collectionHealthScore,
    required this.riskStudents,
    required this.generatedAt,
  });

  final int expectedCollections;
  final int outstandingCollections;
  final int collectionHealthScore;
  final List<FinanceDefaulterPrediction> riskStudents;
  final String generatedAt;
}

@immutable
class FinanceDefaulterPrediction {
  const FinanceDefaulterPrediction({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.outstandingAmount,
    required this.riskScore,
    required this.daysOverdue,
  });

  final String studentId;
  final String studentName;
  final String className;
  final int outstandingAmount;
  final int riskScore;
  final int daysOverdue;
}

@immutable
class FinanceCollectionTrendPoint {
  const FinanceCollectionTrendPoint({
    required this.month,
    required this.collected,
    required this.expected,
  });

  final String month;
  final int collected;
  final int expected;
}

@immutable
class FinanceCollectionRiskAlert {
  const FinanceCollectionRiskAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.detail,
  });

  final String id;
  final String severity;
  final String title;
  final String detail;
}
