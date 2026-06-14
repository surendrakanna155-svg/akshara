import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../student_success/student_success_provider.dart';
import 'promotion_readiness_intelligence.dart';

final promotionReadinessProfilesProvider =
    Provider<AsyncValue<List<PromotionReadinessProfile>>>((ref) {
  final predictions = ref.watch(studentSuccessPredictionsProvider);
  return predictions.whenData(buildPromotionReadinessProfiles);
});

final promotionReadinessSummaryProvider =
    Provider<AsyncValue<PromotionReadinessSummary>>((ref) {
  final profiles = ref.watch(promotionReadinessProfilesProvider);
  return profiles.whenData(summarizePromotionReadiness);
});

final promotionReviewQueueProvider = Provider<AsyncValue<List<PromotionReadinessProfile>>>((ref) {
  final profiles = ref.watch(promotionReadinessProfilesProvider);
  return profiles.whenData(promotionReviewQueue);
});
