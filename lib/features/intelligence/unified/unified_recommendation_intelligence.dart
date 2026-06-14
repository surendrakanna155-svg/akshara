import '../../finance/intelligence/fee_collection_intelligence.dart';
import '../academic/promotion_readiness_intelligence.dart';
import '../operations/operations_intelligence.dart';
import '../student_success/at_risk_student_intelligence.dart';
import '../student_success/attendance_intelligence.dart';
import '../teacher_effectiveness/teacher_intervention_intelligence.dart';

/// Aggregated cross-module recommendations (INTEL-10).
enum UnifiedRecommendationSource {
  atRisk('At-risk student'),
  attendance('Attendance'),
  feeCollection('Fee collection'),
  teacherIntervention('Teacher intervention'),
  promotion('Promotion readiness'),
  operations('Operations');

  const UnifiedRecommendationSource(this.label);

  final String label;
}

class UnifiedRecommendation {
  const UnifiedRecommendation({
    required this.source,
    required this.title,
    required this.detail,
    required this.priorityScore,
    required this.suggestedAction,
  });

  final UnifiedRecommendationSource source;
  final String title;
  final String detail;
  final int priorityScore;
  final String suggestedAction;
}

class UnifiedRecommendationSummary {
  const UnifiedRecommendationSummary({
    required this.totalRecommendations,
    required this.criticalCount,
    required this.topRecommendations,
  });

  final int totalRecommendations;
  final int criticalCount;
  final List<UnifiedRecommendation> topRecommendations;
}

List<UnifiedRecommendation> buildUnifiedRecommendations({
  AtRiskIntelligenceSummary? atRisk,
  AttendanceIntelligenceSummary? attendance,
  FeeCollectionIntelligenceSummary? feeCollection,
  TeacherInterventionSummary? teacherIntervention,
  PromotionReadinessSummary? promotion,
  OperationsIntelligenceSummary? operations,
}) {
  final items = <UnifiedRecommendation>[];

  if (atRisk != null) {
    for (final profile in atRisk.topProfiles.take(5)) {
      items.add(
        UnifiedRecommendation(
          source: UnifiedRecommendationSource.atRisk,
          title: '${profile.studentName} — ${profile.tier.label} dropout risk',
          detail: profile.primarySignal,
          priorityScore: profile.tier.sortOrder * 25 + profile.dropoutProbability ~/ 4,
          suggestedAction: profile.recommendedAction,
        ),
      );
    }
  }

  if (attendance != null) {
    for (final profile in attendance.topProfiles.take(4)) {
      items.add(
        UnifiedRecommendation(
          source: UnifiedRecommendationSource.attendance,
          title: '${profile.studentName} — ${profile.tier.label}',
          detail: profile.primarySignal,
          priorityScore: profile.tier.sortOrder * 20 + (100 - profile.attendancePrediction),
          suggestedAction: profile.recommendedAction,
        ),
      );
    }
  }

  if (feeCollection != null) {
    for (final profile in feeCollection.topProfiles.take(4)) {
      items.add(
        UnifiedRecommendation(
          source: UnifiedRecommendationSource.feeCollection,
          title: '${profile.studentName} — ${profile.tier.label} fee risk',
          detail: '₹${profile.outstandingAmount} · ${profile.daysOverdue}d overdue',
          priorityScore: profile.tier.sortOrder * 22 + profile.riskScore ~/ 3,
          suggestedAction: profile.recommendedAction,
        ),
      );
    }
    for (final alert in feeCollection.alertActions.take(2)) {
      items.add(
        UnifiedRecommendation(
          source: UnifiedRecommendationSource.feeCollection,
          title: 'Collection alert',
          detail: alert,
          priorityScore: 70,
          suggestedAction: 'Review finance copilot alerts and assign accounts follow-up.',
        ),
      );
    }
  }

  if (teacherIntervention != null) {
    for (final suggestion in teacherIntervention.topSuggestions.take(4)) {
      items.add(
        UnifiedRecommendation(
          source: UnifiedRecommendationSource.teacherIntervention,
          title: '${suggestion.studentName} — ${suggestion.priority.label}',
          detail: suggestion.triggerReason,
          priorityScore: suggestion.priority.sortOrder * 24 + 10,
          suggestedAction: suggestion.suggestedIntervention,
        ),
      );
    }
  }

  if (promotion != null) {
    for (final profile in promotion.topProfiles.where((p) => p.readiness != PromotionReadiness.ready).take(4)) {
      items.add(
        UnifiedRecommendation(
          source: UnifiedRecommendationSource.promotion,
          title: '${profile.studentName} — ${profile.readiness.label}',
          detail: 'Readiness score ${profile.readinessScore}',
          priorityScore: profile.readiness.sortOrder * 18 + (100 - profile.readinessScore),
          suggestedAction: profile.recommendedAction,
        ),
      );
    }
  }

  if (operations != null) {
    for (final hint in operations.topHints.take(4)) {
      items.add(
        UnifiedRecommendation(
          source: UnifiedRecommendationSource.operations,
          title: hint.title,
          detail: hint.detail,
          priorityScore: hint.priorityScore,
          suggestedAction: hint.suggestedAction,
        ),
      );
    }
  }

  items.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
  return items;
}

UnifiedRecommendationSummary summarizeUnifiedRecommendations(List<UnifiedRecommendation> items) {
  return UnifiedRecommendationSummary(
    totalRecommendations: items.length,
    criticalCount: items.where((i) => i.priorityScore >= 75).length,
    topRecommendations: items.take(20).toList(growable: false),
  );
}
