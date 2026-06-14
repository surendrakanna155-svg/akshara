import '../student_success/student_success_models.dart';

/// Academic promotion readiness (INTEL-09 — readiness scoring only, not bulk promote).
enum PromotionReadiness {
  ready('Ready to promote', 3),
  borderline('Borderline', 2),
  notReady('Not ready', 1),
  hold('Hold — review required', 0);

  const PromotionReadiness(this.label, this.sortOrder);

  final String label;
  final int sortOrder;
}

class PromotionReadinessProfile {
  const PromotionReadinessProfile({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.readiness,
    required this.readinessScore,
    required this.attendancePrediction,
    required this.improvementScore,
    required this.performanceDeclineScore,
    required this.recommendedAction,
  });

  final String studentId;
  final String studentName;
  final String className;
  final PromotionReadiness readiness;
  final int readinessScore;
  final int attendancePrediction;
  final int improvementScore;
  final int performanceDeclineScore;
  final String recommendedAction;
}

class PromotionReadinessSummary {
  const PromotionReadinessSummary({
    required this.totalAssessed,
    required this.readyCount,
    required this.borderlineCount,
    required this.notReadyCount,
    required this.holdCount,
    required this.topProfiles,
  });

  final int totalAssessed;
  final int readyCount;
  final int borderlineCount;
  final int notReadyCount;
  final int holdCount;
  final List<PromotionReadinessProfile> topProfiles;
}

int computePromotionReadinessScore(StudentSuccessSnapshot snapshot) {
  return ((snapshot.improvementScore * 0.35) +
          (snapshot.attendancePrediction * 0.30) +
          ((100 - snapshot.performanceDeclineScore) * 0.25) +
          ((100 - snapshot.dropoutProbability) * 0.10))
      .round()
      .clamp(0, 100);
}

PromotionReadiness classifyPromotionReadiness(int score, StudentSuccessSnapshot snapshot) {
  if (snapshot.dropoutProbability >= 70 || snapshot.performanceDeclineScore >= 75) {
    return PromotionReadiness.hold;
  }
  if (score >= 75) return PromotionReadiness.ready;
  if (score >= 55) return PromotionReadiness.borderline;
  return PromotionReadiness.notReady;
}

String _promotionAction(PromotionReadiness readiness) => switch (readiness) {
      PromotionReadiness.ready => 'Approve promotion with standard summer bridge materials.',
      PromotionReadiness.borderline =>
        'Assign remedial summer program before final promotion decision.',
      PromotionReadiness.notReady =>
        'Retain in current grade with individualized learning plan.',
      PromotionReadiness.hold =>
        'Convene academic review board before any promotion decision.',
    };

PromotionReadinessProfile promotionProfileFromSnapshot(StudentSuccessSnapshot snapshot) {
  final score = computePromotionReadinessScore(snapshot);
  final readiness = classifyPromotionReadiness(score, snapshot);
  return PromotionReadinessProfile(
    studentId: snapshot.studentId,
    studentName: snapshot.studentName,
    className: snapshot.className,
    readiness: readiness,
    readinessScore: score,
    attendancePrediction: snapshot.attendancePrediction,
    improvementScore: snapshot.improvementScore,
    performanceDeclineScore: snapshot.performanceDeclineScore,
    recommendedAction: _promotionAction(readiness),
  );
}

List<PromotionReadinessProfile> buildPromotionReadinessProfiles(
  List<StudentSuccessSnapshot> snapshots,
) {
  final profiles = snapshots.map(promotionProfileFromSnapshot).toList()
    ..sort((a, b) {
      final readinessCompare = b.readiness.sortOrder.compareTo(a.readiness.sortOrder);
      if (readinessCompare != 0) return readinessCompare;
      return b.readinessScore.compareTo(a.readinessScore);
    });
  return profiles;
}

PromotionReadinessSummary summarizePromotionReadiness(List<PromotionReadinessProfile> profiles) {
  return PromotionReadinessSummary(
    totalAssessed: profiles.length,
    readyCount: profiles.where((p) => p.readiness == PromotionReadiness.ready).length,
    borderlineCount: profiles.where((p) => p.readiness == PromotionReadiness.borderline).length,
    notReadyCount: profiles.where((p) => p.readiness == PromotionReadiness.notReady).length,
    holdCount: profiles.where((p) => p.readiness == PromotionReadiness.hold).length,
    topProfiles: profiles.take(15).toList(growable: false),
  );
}

List<PromotionReadinessProfile> promotionReviewQueue(List<PromotionReadinessProfile> profiles) {
  return profiles
      .where(
        (p) =>
            p.readiness == PromotionReadiness.borderline ||
            p.readiness == PromotionReadiness.hold ||
            p.readiness == PromotionReadiness.notReady,
      )
      .toList(growable: false);
}
