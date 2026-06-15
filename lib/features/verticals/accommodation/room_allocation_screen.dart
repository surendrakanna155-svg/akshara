import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import 'accommodation_providers.dart';

class RoomAllocationScreen extends ConsumerWidget {
  const RoomAllocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(accommodationAccommodationAllocationListProvider);
    return Scaffold(
      key: QaTestKeys.accommodationAccommodationAllocationScreen,
      appBar: AppBar(title: const Text('AccommodationAllocation')),
      body: items.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return ListTile(
              key: QaTestKeys.accommodationAccommodationAllocationTile(item.id),
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
