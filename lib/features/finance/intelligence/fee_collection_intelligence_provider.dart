import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fee_collection_intelligence.dart';
import 'finance_intelligence_provider.dart';

final feeCollectionProfilesProvider = Provider<AsyncValue<List<FeeCollectionProfile>>>((ref) {
  final copilot = ref.watch(financeCopilotProvider);
  return copilot.whenData((data) => buildFeeCollectionProfiles(data.defaulterPredictions));
});

final feeCollectionIntelligenceSummaryProvider =
    Provider<AsyncValue<FeeCollectionIntelligenceSummary>>((ref) {
  final copilot = ref.watch(financeCopilotProvider);
  return copilot.whenData((data) {
    final profiles = buildFeeCollectionProfiles(data.defaulterPredictions);
    return summarizeFeeCollection(profiles, data);
  });
});
