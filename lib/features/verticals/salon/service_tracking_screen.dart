import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import 'salon_providers.dart';

class ServiceTrackingScreen extends ConsumerWidget {
  const ServiceTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(salonSalonServiceListProvider);
    return Scaffold(
      key: QaTestKeys.salonSalonServiceScreen,
      appBar: AppBar(title: const Text('SalonService')),
      body: items.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return ListTile(
              key: QaTestKeys.salonSalonServiceTile(item.id),
              title: Text(item.name),
              subtitle: Text(item.status),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
