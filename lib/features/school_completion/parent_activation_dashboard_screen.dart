import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/widgets.dart';
import 'school_completion_providers.dart';

/// v15.5 — Parent activation, adoption, and engagement dashboard.
class ParentActivationDashboardScreen extends ConsumerWidget {
  const ParentActivationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(parentActivationDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Activation')),
      body: stats.when(
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(parentActivationDashboardProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
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
