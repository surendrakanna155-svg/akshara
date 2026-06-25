import 'package:flutter/foundation.dart';

/// Advanced AI Predictions (B9) — domain models for the three prediction feeds.
/// Every numeric field is computed server-side from real data; the [narrative]
/// is an optional AI summary that safely falls back to a deterministic baseline.

enum PredictionRiskLevel { critical, high, medium, low }

PredictionRiskLevel predictionRiskLevelFromString(Object? v) {
  switch (v?.toString()) {
    case 'critical':
      return PredictionRiskLevel.critical;
    case 'high':
      return PredictionRiskLevel.high;
    case 'medium':
      return PredictionRiskLevel.medium;
    case 'low':
    default:
      return PredictionRiskLevel.low;
  }
}

enum ConversionBand { hot, warm, cool }

ConversionBand conversionBandFromString(Object? v) {
  switch (v?.toString()) {
    case 'hot':
      return ConversionBand.hot;
    case 'warm':
      return ConversionBand.warm;
    case 'cool':
    default:
      return ConversionBand.cool;
  }
}

/// A prediction list plus its (optional) AI narrative.
@immutable
class PredictionFeed<T> {
  const PredictionFeed({required this.items, required this.narrative});

  final List<T> items;
  final String narrative;
}

@immutable
class FeeDefaultPrediction {
  const FeeDefaultPrediction({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.outstandingInr,
    required this.billedInr,
    required this.daysOverdue,
    required this.riskScore,
    required this.riskLevel,
  });

  final String studentId;
  final String studentName;
  final String className;
  final int outstandingInr;
  final int billedInr;
  final int daysOverdue;
  final int riskScore;
  final PredictionRiskLevel riskLevel;
}

@immutable
class AdmissionConversionPrediction {
  const AdmissionConversionPrediction({
    required this.leadId,
    required this.studentName,
    required this.classLabel,
    required this.source,
    required this.stage,
    required this.leadScore,
    required this.ageDays,
    required this.applicationStatus,
    required this.likelihood,
    required this.band,
  });

  final String leadId;
  final String studentName;
  final String classLabel;
  final String source;
  final String stage;
  final String leadScore;
  final int ageDays;
  final String? applicationStatus;
  final int likelihood;
  final ConversionBand band;
}

@immutable
class StudentRiskPrediction {
  const StudentRiskPrediction({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.riskScore,
    required this.riskLevel,
    required this.topReason,
  });

  final String studentId;
  final String studentName;
  final String className;
  final int riskScore;
  final PredictionRiskLevel riskLevel;
  final String topReason;
}
