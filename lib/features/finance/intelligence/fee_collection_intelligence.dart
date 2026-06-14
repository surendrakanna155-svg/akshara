import 'finance_intelligence_models.dart';

/// Fee collection risk tiers (INTEL-08).
enum FeeCollectionRiskTier {
  low('Low', 0),
  medium('Medium', 1),
  high('High', 2),
  critical('Critical', 3);

  const FeeCollectionRiskTier(this.label, this.sortOrder);

  final String label;
  final int sortOrder;
}

class FeeCollectionProfile {
  const FeeCollectionProfile({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.tier,
    required this.outstandingAmount,
    required this.daysOverdue,
    required this.riskScore,
    required this.recommendedAction,
  });

  final String studentId;
  final String studentName;
  final String className;
  final FeeCollectionRiskTier tier;
  final int outstandingAmount;
  final int daysOverdue;
  final int riskScore;
  final String recommendedAction;
}

class FeeCollectionIntelligenceSummary {
  const FeeCollectionIntelligenceSummary({
    required this.totalFlagged,
    required this.criticalCount,
    required this.highCount,
    required this.totalOutstanding,
    required this.collectionGapPercent,
    required this.topProfiles,
    required this.alertActions,
  });

  final int totalFlagged;
  final int criticalCount;
  final int highCount;
  final int totalOutstanding;
  final int collectionGapPercent;
  final List<FeeCollectionProfile> topProfiles;
  final List<String> alertActions;
}

FeeCollectionRiskTier classifyFeeCollectionTier(FinanceDefaulterPrediction prediction) {
  if (prediction.riskScore >= 85 || prediction.daysOverdue >= 60) {
    return FeeCollectionRiskTier.critical;
  }
  if (prediction.riskScore >= 65 || prediction.daysOverdue >= 30) {
    return FeeCollectionRiskTier.high;
  }
  if (prediction.riskScore >= 40 || prediction.daysOverdue >= 14) {
    return FeeCollectionRiskTier.medium;
  }
  return FeeCollectionRiskTier.low;
}

String _feeActionForTier(FeeCollectionRiskTier tier, int outstanding) => switch (tier) {
      FeeCollectionRiskTier.critical =>
        'Issue final notice and schedule fee committee review (₹$outstanding outstanding).',
      FeeCollectionRiskTier.high =>
        'Assign accounts follow-up call and offer structured payment plan.',
      FeeCollectionRiskTier.medium => 'Send automated reminder and parent SMS within 48 hours.',
      FeeCollectionRiskTier.low => 'Include in monthly collection report.',
    };

FeeCollectionProfile feeProfileFromPrediction(FinanceDefaulterPrediction prediction) {
  final tier = classifyFeeCollectionTier(prediction);
  return FeeCollectionProfile(
    studentId: prediction.studentId,
    studentName: prediction.studentName,
    className: prediction.className,
    tier: tier,
    outstandingAmount: prediction.outstandingAmount,
    daysOverdue: prediction.daysOverdue,
    riskScore: prediction.riskScore,
    recommendedAction: _feeActionForTier(tier, prediction.outstandingAmount),
  );
}

List<FeeCollectionProfile> buildFeeCollectionProfiles(
  List<FinanceDefaulterPrediction> predictions, {
  FeeCollectionRiskTier minimumTier = FeeCollectionRiskTier.medium,
}) {
  final profiles = predictions.map(feeProfileFromPrediction).toList()
    ..sort((a, b) {
      final tierCompare = b.tier.sortOrder.compareTo(a.tier.sortOrder);
      if (tierCompare != 0) return tierCompare;
      return b.riskScore.compareTo(a.riskScore);
    });

  return profiles
      .where((p) => p.tier.sortOrder >= minimumTier.sortOrder)
      .toList(growable: false);
}

int _collectionGapPercent(List<FinanceCollectionTrendPoint> trend) {
  if (trend.isEmpty) return 0;
  final expected = trend.map((t) => t.expected).reduce((a, b) => a + b);
  if (expected == 0) return 0;
  final collected = trend.map((t) => t.collected).reduce((a, b) => a + b);
  return (((expected - collected) / expected) * 100).round().clamp(0, 100);
}

List<String> buildFeeAlertActions(List<FinanceCollectionRiskAlert> alerts) {
  return alerts
      .map((a) => '${a.title}: ${a.detail}')
      .take(5)
      .toList(growable: false);
}

FeeCollectionIntelligenceSummary summarizeFeeCollection(
  List<FeeCollectionProfile> profiles,
  FinanceCopilotData data,
) {
  final totalOutstanding = profiles.map((p) => p.outstandingAmount).fold(0, (a, b) => a + b);

  return FeeCollectionIntelligenceSummary(
    totalFlagged: profiles.length,
    criticalCount: profiles.where((p) => p.tier == FeeCollectionRiskTier.critical).length,
    highCount: profiles.where((p) => p.tier == FeeCollectionRiskTier.high).length,
    totalOutstanding: totalOutstanding,
    collectionGapPercent: _collectionGapPercent(data.collectionTrend),
    topProfiles: profiles.take(12).toList(growable: false),
    alertActions: buildFeeAlertActions(data.riskAlerts),
  );
}
