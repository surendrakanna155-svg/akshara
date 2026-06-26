import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import 'accommodation_providers.dart';
import '../../../theme/spacing.dart';

class AccommodationIntelligenceScreen extends ConsumerWidget {
  const AccommodationIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(accommodationIntelligenceProvider);
    return Scaffold(
      key: QaTestKeys.accommodationIntelligenceScreen,
      appBar: AppBar(title: const Text('Intelligence')),
      body: intel.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s6),
          children: [
            ...data.recommendations.map((r) => ListTile(title: Text(r))),
            ...data.insights.map((i) => ListTile(subtitle: Text(i))),
          ],
        ),
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(e),
          onRetry: () => ref.invalidate(accommodationIntelligenceProvider),
        ),
      ),
    );
  }
}
