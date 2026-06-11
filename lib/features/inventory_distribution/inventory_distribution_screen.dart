import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../phase4/phase4_providers.dart';
import '../phase5/phase5_providers.dart';

class InventoryDistributionScreen extends ConsumerWidget {
  const InventoryDistributionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(inventoryDistributionDashboardProvider);
    final items = ref.watch(inventoryDistributionsListProvider);
    final reports = ref.watch(distributionReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Distribution')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          dashboard.when(
            data: (d) => Column(
              children: [
                ListTile(title: const Text('Pending'), trailing: Text('${d.pendingDistributions}')),
                ListTile(title: const Text('Replacements'), trailing: Text('${d.replacementRequests}')),
                ListTile(title: const Text('Payment pending'), trailing: Text('${d.paymentPending}')),
                ListTile(title: const Text('Distributed today'), trailing: Text('${d.distributedToday}')),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          const SizedBox(height: 16),
          Text('Student distributions', style: Theme.of(context).textTheme.titleMedium),
          items.when(
            data: (list) => Column(
              children: list
                  .map(
                    (i) => ListTile(
                      title: Text(i.itemName ?? i.catalogItemId),
                      subtitle: Text('${i.category} · ${i.status}'),
                      trailing: Text('x${i.quantity}'),
                    ),
                  )
                  .toList(),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          const SizedBox(height: 16),
          Text('Distribution reports', style: Theme.of(context).textTheme.titleMedium),
          reports.when(
            data: (r) => Column(
              children: [
                ListTile(title: const Text('Pending'), trailing: Text('${r.pending}')),
                ListTile(title: const Text('Issued'), trailing: Text('${r.issued}')),
                ListTile(title: const Text('Replacement'), trailing: Text('${r.replacement}')),
                ListTile(title: const Text('Lost'), trailing: Text('${r.lost}')),
                ListTile(title: const Text('Damaged'), trailing: Text('${r.damaged}')),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await ref.read(inventoryDistributionRepositoryProvider).transitionStatus(
                    query: ref.read(phase4QueryProvider),
                    distributionId: 'dist_2',
                    status: 'distributed',
                  );
              ref.invalidate(inventoryDistributionsListProvider);
              ref.invalidate(inventoryDistributionDashboardProvider);
            },
            child: const Text('Mark demo distribution as distributed'),
          ),
        ],
      ),
    );
  }
}
