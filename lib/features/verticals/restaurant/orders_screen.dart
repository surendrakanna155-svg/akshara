import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import 'restaurant_providers.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(restaurantRestaurantOrderListProvider);
    return Scaffold(
      key: QaTestKeys.restaurantRestaurantOrderScreen,
      appBar: AppBar(title: const Text('RestaurantOrder')),
      body: items.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return ListTile(
              key: QaTestKeys.restaurantRestaurantOrderTile(item.id),
              title: Text(item.name),
              subtitle: Text(item.status),
            );
          },
        ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading orders'),
        error: (e, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(e),
          onRetry: () => ref.invalidate(restaurantRestaurantOrderListProvider),
        ),
      ),
    );
  }
}
