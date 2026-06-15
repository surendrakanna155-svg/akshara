import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import 'restaurant_providers.dart';

class RestaurantDashboardScreen extends ConsumerWidget {
  const RestaurantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(restaurantCanViewProvider)) {
      return const Scaffold(body: Center(child: Text('Permission required.')));
    }
    final dashboard = ref.watch(restaurantDashboardProvider);
    return Scaffold(
      key: QaTestKeys.restaurantDashboardScreen,
      appBar: AppBar(title: const Text('Restaurant')),
      body: dashboard.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(data.summary, key: QaTestKeys.restaurantDashboardSummary),
            const SizedBox(height: 16),
            ...data.kpis.map(
              (kpi) => ListTile(
                key: QaTestKeys.restaurantKpiTile(kpi.id),
                title: Text(kpi.label),
                trailing: Text(kpi.value),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 8, children: [
                ElevatedButton(
                  key: QaTestKeys.restaurantNavLink('restaurantTables'),
                  onPressed: () => context.go(RouteNames.restaurantTables),
                  child: const Text('Tables'),
                ),
                ElevatedButton(
                  key: QaTestKeys.restaurantNavLink('restaurantOrders'),
                  onPressed: () => context.go(RouteNames.restaurantOrders),
                  child: const Text('Orders'),
                ),
                ElevatedButton(
                  key: QaTestKeys.restaurantNavLink('restaurantKitchen'),
                  onPressed: () => context.go(RouteNames.restaurantKitchen),
                  child: const Text('Kitchen'),
                ),
                ElevatedButton(
                  key: QaTestKeys.restaurantNavLink('restaurantIntelligence'),
                  onPressed: () => context.go(RouteNames.restaurantIntelligence),
                  child: const Text('Intelligence'),
                ),
            ]),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
