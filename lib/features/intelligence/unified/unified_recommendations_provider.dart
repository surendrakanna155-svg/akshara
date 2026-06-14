import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../finance/intelligence/fee_collection_intelligence_provider.dart';
import '../academic/promotion_readiness_provider.dart';
import '../operations/operations_intelligence_provider.dart';
import '../student_success/at_risk_student_provider.dart';
import '../student_success/attendance_intelligence_provider.dart';
import '../teacher_effectiveness/teacher_intervention_provider.dart';
import 'unified_recommendation_intelligence.dart';

final unifiedRecommendationsProvider = Provider<AsyncValue<List<UnifiedRecommendation>>>((ref) {
  final atRisk = ref.watch(atRiskIntelligenceSummaryProvider);
  final attendance = ref.watch(attendanceIntelligenceSummaryProvider);
  final fee = ref.watch(feeCollectionIntelligenceSummaryProvider);
  final teacher = ref.watch(teacherInterventionSummaryProvider);
  final promotion = ref.watch(promotionReadinessSummaryProvider);
  final operations = ref.watch(operationsIntelligenceSummaryProvider);

  if (atRisk.isLoading ||
      attendance.isLoading ||
      fee.isLoading ||
      teacher.isLoading ||
      promotion.isLoading ||
      operations.isLoading) {
    return const AsyncValue.loading();
  }

  final error = atRisk.error ??
      attendance.error ??
      fee.error ??
      teacher.error ??
      promotion.error ??
      operations.error;
  if (error != null) {
    return AsyncValue.error(error, StackTrace.current);
  }

  return AsyncValue.data(
    buildUnifiedRecommendations(
      atRisk: atRisk.valueOrNull,
      attendance: attendance.valueOrNull,
      feeCollection: fee.valueOrNull,
      teacherIntervention: teacher.valueOrNull,
      promotion: promotion.valueOrNull,
      operations: operations.valueOrNull,
    ),
  );
});

final unifiedRecommendationSummaryProvider =
    Provider<AsyncValue<UnifiedRecommendationSummary>>((ref) {
  final recommendations = ref.watch(unifiedRecommendationsProvider);
  return recommendations.whenData(summarizeUnifiedRecommendations);
});
