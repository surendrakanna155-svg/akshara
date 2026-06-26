import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import 'healthcare_providers.dart';
import '../../../theme/spacing.dart';

class HealthcareDashboardScreen extends ConsumerWidget {
  const HealthcareDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(healthcareCanViewProvider)) {
      return const Scaffold(body: Center(child: Text('Permission required.')));
    }
    final dashboard = ref.watch(healthcareDashboardProvider);
    return Scaffold(
      key: QaTestKeys.healthcareDashboardScreen,
      appBar: AppBar(title: const Text('Healthcare')),
      body: dashboard.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s6),
          children: [
            Text(data.summary, key: QaTestKeys.healthcareDashboardSummary),
            const SizedBox(height: 16),
            ...data.kpis.map(
              (kpi) => ListTile(
                key: QaTestKeys.healthcareKpiTile(kpi.id),
                title: Text(kpi.label),
                trailing: Text(kpi.value),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 8, children: [
                ElevatedButton(
                  key: QaTestKeys.healthcareNavLink('healthcarePatients'),
                  onPressed: () => context.go(RouteNames.healthcarePatients),
                  child: const Text('Patients'),
                ),
                ElevatedButton(
                  key: QaTestKeys.healthcareNavLink('healthcareAppointments'),
                  onPressed: () => context.go(RouteNames.healthcareAppointments),
                  child: const Text('Appointments'),
                ),
                ElevatedButton(
                  key: QaTestKeys.healthcareNavLink('healthcarePractitioners'),
                  onPressed: () => context.go(RouteNames.healthcarePractitioners),
                  child: const Text('Practitioners'),
                ),
                ElevatedButton(
                  key: QaTestKeys.healthcareNavLink('healthcareIntelligence'),
                  onPressed: () => context.go(RouteNames.healthcareIntelligence),
                  child: const Text('Intelligence'),
                ),
            ]),
          ],
        ),
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(e),
          onRetry: () => ref.invalidate(healthcareDashboardProvider),
        ),
      ),
    );
  }
}
