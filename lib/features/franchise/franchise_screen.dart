import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'franchise_mutations_provider.dart';
import 'franchise_providers.dart';

class FranchiseScreen extends ConsumerWidget {
  const FranchiseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canViewFranchiseOperationsProvider)) {
      return const Scaffold(
        body: Center(child: Text('Franchise operations permission required.')),
      );
    }
    final dashboard = ref.watch(franchiseDashboardProvider);
    return Scaffold(
      key: QaTestKeys.franchiseScreen,
      appBar: AppBar(title: const Text('Franchise Portfolio')),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: data.portfolioKpis
                  .map(
                    (kpi) => SizedBox(
                      width: 260,
                      child: Card(
                        child: ListTile(
                          title: Text(kpi.label),
                          subtitle: Text(kpi.delta),
                          trailing: Text(kpi.value),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const Divider(),
            ...data.franchises.map(
              (franchise) => Card(
                child: ListTile(
                  key: QaTestKeys.franchiseTile(franchise.id),
                  title: Text(franchise.name),
                  subtitle: Text(
                    '${franchise.region} • ${franchise.schoolCount} schools',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      Chip(label: Text('KPI ${franchise.kpiScore}')),
                      IconButton(
                        key: QaTestKeys.franchiseImproveButton(franchise.id),
                        tooltip: 'Improve KPI',
                        onPressed: () => _improve(context, ref, franchise.id),
                        icon: const Icon(Icons.trending_up),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _improve(
    BuildContext context,
    WidgetRef ref,
    String franchiseId,
  ) async {
    final result = await ref
        .read(franchiseMutationsProvider.notifier)
        .improveScore(franchiseId: franchiseId);
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.franchiseUpdatedSnackbar,
        content: Text('Franchise KPI updated.'),
      ),
    );
  }
}
