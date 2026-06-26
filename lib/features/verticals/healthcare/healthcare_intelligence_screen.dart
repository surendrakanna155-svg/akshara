import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import 'healthcare_providers.dart';
import '../../../theme/spacing.dart';

class HealthcareIntelligenceScreen extends ConsumerWidget {
  const HealthcareIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(healthcareIntelligenceProvider);
    return Scaffold(
      key: QaTestKeys.healthcareIntelligenceScreen,
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
          onRetry: () => ref.invalidate(healthcareIntelligenceProvider),
        ),
      ),
    );
  }
}
