import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../inventory_models.dart';
import '../widgets/inventory_module_scaffold.dart';
import 'inventory_intelligence_models.dart';
import 'inventory_intelligence_provider.dart';

/// Asset Lifecycle — purchase, distribution, replacement, damage, retirement tracking.
class InventoryLifecycleScreen extends ConsumerWidget {
  const InventoryLifecycleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifecycle = ref.watch(assetLifecycleProvider);
    final procurement = ref.watch(procurementWorkflowProvider);

    return KeyedSubtree(
      key: QaTestKeys.inventoryLifecycleScreen,
      child: InventoryModuleScaffold(
        screen: InventoryScreen.lifecycle,
        showFilterBar: false,
        body: lifecycle.when(
          loading: () => const AksharaLoadingState(),
          error: (e, _) => AksharaErrorState(message: '$e'),
          data: (snapshot) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _metric('Assets tracked', '${snapshot.assetsTracked}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AssetLifecycleEventType.values.map((type) {
                  final count = snapshot.eventCounts[type] ?? 0;
                  return Chip(label: Text('${type.label}: $count'));
                }).toList(),
              ),
              procurement.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (proc) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 32),
                    const Text(
                      'Procurement workflow',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _metric('Pending approvals', '${proc.pendingApprovals}'),
                    _metric('Overdue deliveries', '${proc.overdueDeliveries}'),
                    ...proc.alerts.map(
                      (a) => AksharaWarningBanner(
                        message: '${a.title}: ${a.detail}',
                      ),
                    ),
                    ...proc.recommendations.map(
                      (r) => ListTile(
                        title: Text(r.poNumber),
                        subtitle: Text(r.action),
                        trailing: Text(r.priority),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              const Text(
                'Recent lifecycle events',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (snapshot.recentEvents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: AksharaEmptyState(
                    message: 'No lifecycle events recorded yet',
                  ),
                )
              else
                ...snapshot.recentEvents.map(
                  (e) => ListTile(
                    leading: Icon(_iconForEvent(e.eventType)),
                    title: Text(
                      '${e.eventType.label} — ${e.assetTag.isNotEmpty ? e.assetTag : e.assetId}',
                    ),
                    subtitle: Text(
                      e.notes.isNotEmpty ? e.notes : e.recordedAt,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _metric(String label, String value) {
  return ListTile(
    title: Text(label),
    trailing: Text(
      value,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  );
}

IconData _iconForEvent(AssetLifecycleEventType type) => switch (type) {
      AssetLifecycleEventType.purchase => Icons.shopping_cart_outlined,
      AssetLifecycleEventType.distribution => Icons.share_outlined,
      AssetLifecycleEventType.replacement => Icons.swap_horiz,
      AssetLifecycleEventType.damage => Icons.warning_amber_outlined,
      AssetLifecycleEventType.retirement => Icons.archive_outlined,
    };
