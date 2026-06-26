import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import 'accommodation_providers.dart';
import '../../../theme/spacing.dart';

class AccommodationDashboardScreen extends ConsumerWidget {
  const AccommodationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(accommodationCanViewProvider)) {
      return const Scaffold(body: Center(child: Text('Permission required.')));
    }
    final dashboard = ref.watch(accommodationDashboardProvider);
    return Scaffold(
      key: QaTestKeys.accommodationDashboardScreen,
      appBar: AppBar(title: const Text('Accommodation')),
      body: dashboard.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s6),
          children: [
            Text(data.summary, key: QaTestKeys.accommodationDashboardSummary),
            const SizedBox(height: 16),
            ...data.kpis.map(
              (kpi) => ListTile(
                key: QaTestKeys.accommodationKpiTile(kpi.id),
                title: Text(kpi.label),
                trailing: Text(kpi.value),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 8, children: [
                ElevatedButton(
                  key: QaTestKeys.accommodationNavLink('accommodationResidents'),
                  onPressed: () => context.go(RouteNames.accommodationResidents),
                  child: const Text('Residents'),
                ),
                ElevatedButton(
                  key: QaTestKeys.accommodationNavLink('accommodationOccupancy'),
                  onPressed: () => context.go(RouteNames.accommodationOccupancy),
                  child: const Text('Occupancy'),
                ),
                ElevatedButton(
                  key: QaTestKeys.accommodationNavLink('accommodationAllocations'),
                  onPressed: () => context.go(RouteNames.accommodationAllocations),
                  child: const Text('Allocations'),
                ),
                ElevatedButton(
                  key: QaTestKeys.accommodationNavLink('accommodationIntelligence'),
                  onPressed: () => context.go(RouteNames.accommodationIntelligence),
                  child: const Text('Intelligence'),
                ),
                ElevatedButton(
                  key: QaTestKeys.accommodationNavLink('hostelDashboard'),
                  onPressed: () => context.go(RouteNames.hostelDashboard),
                  child: const Text('Hostel ERP'),
                ),
            ]),
          ],
        ),
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(e),
          onRetry: () => ref.invalidate(accommodationDashboardProvider),
        ),
      ),
    );
  }
}
