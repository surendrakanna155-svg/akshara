import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import 'restaurant_providers.dart';

class HospitalityIntelligenceScreen extends ConsumerWidget {
  const HospitalityIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(restaurantIntelligenceProvider);
    return Scaffold(
      key: QaTestKeys.restaurantIntelligenceScreen,
      appBar: AppBar(title: const Text('Intelligence')),
      body: intel.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ...data.recommendations.map((r) => ListTile(title: Text(r))),
            ...data.insights.map((i) => ListTile(subtitle: Text(i))),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
