import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import 'restaurant_providers.dart';

class KitchenWorkflowScreen extends ConsumerWidget {
  const KitchenWorkflowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(restaurantKitchenTicketListProvider);
    return Scaffold(
      key: QaTestKeys.restaurantKitchenTicketScreen,
      appBar: AppBar(title: const Text('KitchenTicket')),
      body: items.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return ListTile(
              key: QaTestKeys.restaurantKitchenTicketTile(item.id),
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
