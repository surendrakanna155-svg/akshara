import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import 'salon_providers.dart';
import '../../../theme/spacing.dart';

class SalonDashboardScreen extends ConsumerWidget {
  const SalonDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(salonCanViewProvider)) {
      return const Scaffold(body: Center(child: Text('Permission required.')));
    }
    final dashboard = ref.watch(salonDashboardProvider);
    return Scaffold(
      key: QaTestKeys.salonDashboardScreen,
      appBar: AppBar(title: const Text('Salon')),
      body: dashboard.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s6),
          children: [
            Text(data.summary, key: QaTestKeys.salonDashboardSummary),
            const SizedBox(height: 16),
            ...data.kpis.map(
              (kpi) => ListTile(
                key: QaTestKeys.salonKpiTile(kpi.id),
                title: Text(kpi.label),
                trailing: Text(kpi.value),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 8, children: [
                ElevatedButton(
                  key: QaTestKeys.salonNavLink('salonCustomers'),
                  onPressed: () => context.go(RouteNames.salonCustomers),
                  child: const Text('Customers'),
                ),
                ElevatedButton(
                  key: QaTestKeys.salonNavLink('salonAppointments'),
                  onPressed: () => context.go(RouteNames.salonAppointments),
                  child: const Text('Appointments'),
                ),
                ElevatedButton(
                  key: QaTestKeys.salonNavLink('salonServices'),
                  onPressed: () => context.go(RouteNames.salonServices),
                  child: const Text('Services'),
                ),
                ElevatedButton(
                  key: QaTestKeys.salonNavLink('salonIntelligence'),
                  onPressed: () => context.go(RouteNames.salonIntelligence),
                  child: const Text('Intelligence'),
                ),
            ]),
          ],
        ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading dashboard'),
        error: (e, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(e),
          onRetry: () => ref.invalidate(salonDashboardProvider),
        ),
      ),
    );
  }
}
