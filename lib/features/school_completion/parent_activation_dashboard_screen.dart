import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/async/erp_async_state.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

/// v15.5 — Parent activation, adoption, and engagement dashboard.
class ParentActivationDashboardScreen extends ConsumerWidget {
  const ParentActivationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(parentActivationDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Activation')),
      body: ErpAsyncBody(
        state: resolveErpAsync(stats, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No parent activation data available.',
        onRetry: () => ref.invalidate(parentActivationDashboardProvider),
        builder: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            _metricCard('Activation rate', '${data.activationRate}%'),
            _metricCard('Adoption rate', '${data.adoptionRate}%'),
            _metricCard('Active parents', '${data.active}/${data.total}'),
            _metricCard('Pending activation', '${data.pending}'),
            _metricCard('Daily active parents', '${data.dailyActiveParents}'),
            _metricCard('Monthly active parents', '${data.monthlyActiveParents}'),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }
}
