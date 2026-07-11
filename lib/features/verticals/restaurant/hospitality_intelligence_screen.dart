import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import 'restaurant_providers.dart';
import '../../../theme/spacing.dart';

class HospitalityIntelligenceScreen extends ConsumerWidget {
  const HospitalityIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(restaurantIntelligenceProvider);
    return Scaffold(
      key: QaTestKeys.restaurantIntelligenceScreen,
      appBar: AppBar(title: const Text('Analytics')),
      body: intel.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s6),
          children: [
            ...data.recommendations.map((r) => ListTile(title: Text(r))),
            ...data.insights.map((i) => ListTile(subtitle: Text(i))),
          ],
        ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading intelligence'),
        error: (e, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(e),
          onRetry: () => ref.invalidate(restaurantIntelligenceProvider),
        ),
      ),
    );
  }
}
