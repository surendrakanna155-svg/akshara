import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import 'salon_providers.dart';

class BusinessIntelligenceScreen extends ConsumerWidget {
  const BusinessIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(salonIntelligenceProvider);
    return Scaffold(
      key: QaTestKeys.salonIntelligenceScreen,
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
