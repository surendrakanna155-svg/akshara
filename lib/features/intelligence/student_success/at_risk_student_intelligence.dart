import 'student_success_models.dart';

/// Deterministic at-risk tiers before live ML models (INTEL-05 Track D).
enum AtRiskTier {
  low('Low', 0),
  medium('Medium', 1),
  high('High', 2),
  critical('Critical', 3);

  const AtRiskTier(this.label, this.sortOrder);

  final String label;
  final int sortOrder;
}

class AtRiskStudentProfile {
  const AtRiskStudentProfile({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.tier,
    required this.dropoutProbability,
    required this.attendancePrediction,
    required this.performanceDeclineScore,
    required this.primarySignal,
    required this.recommendedAction,
  });

  final String studentId;
  final String studentName;
  final String className;
  final AtRiskTier tier;
  final int dropoutProbability;
  final int attendancePrediction;
  final int performanceDeclineScore;
  final String primarySignal;
  final String recommendedAction;
}

AtRiskTier classifyAtRiskTier(StudentSuccessSnapshot snapshot) {
  final composite = _compositeRiskScore(snapshot);
  if (composite >= 80 || snapshot.dropoutProbability >= 75) {
    return AtRiskTier.critical;
  }
  if (composite >= 60 || snapshot.dropoutProbability >= 55) {
    return AtRiskTier.high;
  }
  if (composite >= 40 || snapshot.dropoutProbability >= 35) {
    return AtRiskTier.medium;
  }
  return AtRiskTier.low;
}

int _compositeRiskScore(StudentSuccessSnapshot snapshot) {
  return ((snapshot.dropoutProbability * 0.45) +
          ((100 - snapshot.attendancePrediction) * 0.35) +
          (snapshot.performanceDeclineScore * 0.20))
      .round()
      .clamp(0, 100);
}

AtRiskStudentProfile atRiskProfileFromSnapshot(StudentSuccessSnapshot snapshot) {
  final tier = classifyAtRiskTier(snapshot);
  final signal = snapshot.riskSignals.isNotEmpty
      ? snapshot.riskSignals.first['label']?.toString() ?? 'Multiple risk signals'
      : 'Composite risk score';

  return AtRiskStudentProfile(
    studentId: snapshot.studentId,
    studentName: snapshot.studentName,
    className: snapshot.className,
    tier: tier,
    dropoutProbability: snapshot.dropoutProbability,
    attendancePrediction: snapshot.attendancePrediction,
    performanceDeclineScore: snapshot.performanceDeclineScore,
    primarySignal: signal,
    recommendedAction: _recommendedActionForTier(tier),
  );
}

String _recommendedActionForTier(AtRiskTier tier) => switch (tier) {
      AtRiskTier.critical =>
        'Schedule principal + class teacher review within 48 hours.',
      AtRiskTier.high =>
        'Assign mentor check-in and notify parent about attendance/performance.',
      AtRiskTier.medium =>
        'Monitor weekly and assign targeted homework support.',
      AtRiskTier.low => 'Continue standard monitoring.',
    };

List<AtRiskStudentProfile> buildAtRiskProfiles(
  List<StudentSuccessSnapshot> snapshots, {
  AtRiskTier minimumTier = AtRiskTier.medium,
}) {
  final profiles = snapshots.map(atRiskProfileFromSnapshot).toList()
    ..sort((a, b) {
      final tierCompare = b.tier.sortOrder.compareTo(a.tier.sortOrder);
      if (tierCompare != 0) return tierCompare;
      return b.dropoutProbability.compareTo(a.dropoutProbability);
    });

  return profiles
      .where((profile) => profile.tier.sortOrder >= minimumTier.sortOrder)
      .toList(growable: false);
}

class AtRiskIntelligenceSummary {
  const AtRiskIntelligenceSummary({
    required this.totalFlagged,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.topProfiles,
  });

  final int totalFlagged;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final List<AtRiskStudentProfile> topProfiles;
}

AtRiskIntelligenceSummary summarizeAtRiskProfiles(List<AtRiskStudentProfile> profiles) {
  return AtRiskIntelligenceSummary(
    totalFlagged: profiles.length,
    criticalCount: profiles.where((p) => p.tier == AtRiskTier.critical).length,
    highCount: profiles.where((p) => p.tier == AtRiskTier.high).length,
    mediumCount: profiles.where((p) => p.tier == AtRiskTier.medium).length,
    topProfiles: profiles.take(10).toList(growable: false),
  );
}
