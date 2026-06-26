import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../phase4/phase4_providers.dart';
import '../../phase5/phase5_providers.dart';
import 'inventory_distribution_models.dart';
import 'inventory_distribution_mutations_provider.dart';

class InventoryDistributionScreen extends ConsumerWidget {
  const InventoryDistributionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(inventoryDistributionDashboardProvider);
    final items = ref.watch(inventoryDistributionsListProvider);
    final reports = ref.watch(distributionReportsProvider);

    return Scaffold(
      key: QaTestKeys.inventoryDistributionScreen,
      appBar: AppBar(
        title: const Text('Inventory Distribution'),
        actions: [
          IconButton(
            key: QaTestKeys.inventoryDistributionReplacementsLink,
            tooltip: 'Replacement workflow',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => context.go(RouteNames.inventoryReplacements),
          ),
        ],
      ),
      floatingActionButton: AksharaManageAction(
        permission: Permission.manageInventoryDistribution,
        child: FloatingActionButton.extended(
          key: QaTestKeys.inventoryDistributionCreateFab,
          onPressed: () => _showCreateDistributionDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Create distribution'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          dashboard.when(
            data: (d) => _KpiSection(dashboard: d),
            loading: () => const AksharaLoadingState(),
            error: (e, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(e),
              onRetry: () =>
                  ref.invalidate(inventoryDistributionDashboardProvider),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          Text(
            'Student distributions',
            style: context.aksharaText.titleMedium,
          ),
          const SizedBox(height: AksharaSpacing.s2),
          items.when(
            data: (list) => list.isEmpty
                ? const AksharaEmptyState(
                    message: 'No distributions available.',
                    icon: Icons.inventory_2_outlined,
                  )
                : Column(
                    children: [
                      for (final distribution in list) ...[
                        _DistributionCard(distribution: distribution),
                        const SizedBox(height: AksharaSpacing.s3),
                      ],
                    ],
                  ),
            loading: () => const AksharaLoadingState(),
            error: (e, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(e),
              onRetry: () => ref.invalidate(inventoryDistributionsListProvider),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          Text(
            'Distribution reports',
            style: context.aksharaText.titleMedium,
          ),
          const SizedBox(height: AksharaSpacing.s2),
          reports.when(
            data: (r) => Column(
              children: [
                ListTile(
                  title: const Text('Pending'),
                  trailing: Text('${r.pending}'),
                ),
                ListTile(
                  title: const Text('Issued'),
                  trailing: Text('${r.issued}'),
                ),
                ListTile(
                  title: const Text('Replacement'),
                  trailing: Text('${r.replacement}'),
                ),
                ListTile(
                    title: const Text('Lost'), trailing: Text('${r.lost}')),
                ListTile(
                  title: const Text('Damaged'),
                  trailing: Text('${r.damaged}'),
                ),
              ],
            ),
            loading: () => const AksharaLoadingState(),
            error: (e, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(e),
              onRetry: () => ref.invalidate(distributionReportsProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.dashboard});

  final InvDistributionDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AksharaSpacing.s3,
      runSpacing: AksharaSpacing.s3,
      children: [
        _KpiCard(
          title: 'Pending',
          value: dashboard.pendingDistributions.toString(),
          icon: Icons.pending_actions_outlined,
        ),
        _KpiCard(
          title: 'Replacement requests',
          value: dashboard.replacementRequests.toString(),
          icon: Icons.sync_problem_outlined,
          onTap: () => context.go(RouteNames.inventoryReplacements),
        ),
        _KpiCard(
          title: 'Payment pending',
          value: dashboard.paymentPending.toString(),
          icon: Icons.payments_outlined,
        ),
        _KpiCard(
          title: 'Distributed today',
          value: dashboard.distributedToday.toString(),
          icon: Icons.check_circle_outline,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20),
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  value,
                  style: context.aksharaText.headlineSmall,
                ),
                const SizedBox(height: AksharaSpacing.s1),
                Text(title),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DistributionCard extends ConsumerWidget {
  const _DistributionCard({required this.distribution});

  final InvStudentDistribution distribution;

  bool get _isPending =>
      distribution.status == 'pending' || distribution.status == 'available';

  bool get _canRequestReplacement =>
      distribution.status == 'distributed' || distribution.status == 'damaged';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: QaTestKeys.inventoryDistributionRow(distribution.id),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    distribution.itemName ?? distribution.catalogItemId,
                    style: context.aksharaText.titleSmall,
                  ),
                ),
                _DistributionStatusChip(status: distribution.status),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s1),
            Text('Student: ${distribution.studentId}'),
            Text('Category: ${distribution.category ?? '—'}'),
            Text('Quantity: ${distribution.quantity}'),
            const SizedBox(height: AksharaSpacing.s2),
            Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                if (_isPending)
                  AksharaManageAction(
                    permission: Permission.manageInventoryDistribution,
                    child: FilledButton.tonal(
                      key:
                          QaTestKeys.inventoryDistributionMarkDistributedButton(
                        distribution.id,
                      ),
                      onPressed: () async {
                        final result = await ref
                            .read(markDistributedProvider.notifier)
                            .execute(distributionId: distribution.id);
                        if (!context.mounted || result == null) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            key: QaTestKeys
                                .inventoryDistributionMarkDistributedSuccessSnackbar,
                            content:
                                Text('Distribution marked as distributed.'),
                          ),
                        );
                      },
                      child: const Text('Mark distributed'),
                    ),
                  ),
                if (_canRequestReplacement)
                  AksharaManageAction(
                    permission: Permission.manageInventoryDistribution,
                    child: FilledButton.tonal(
                      key: QaTestKeys
                          .inventoryDistributionRequestReplacementButton(
                        distribution.id,
                      ),
                      onPressed: () async {
                        final result = await ref
                            .read(requestReplacementProvider.notifier)
                            .execute(distributionId: distribution.id);
                        if (!context.mounted || result == null) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            key: QaTestKeys
                                .inventoryDistributionReplacementSuccessSnackbar,
                            content: Text('Replacement requested.'),
                          ),
                        );
                      },
                      child: const Text('Request replacement'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionStatusChip extends StatelessWidget {
  const _DistributionStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final (label, tone) = switch (normalized) {
      'distributed' => ('Distributed', KpiAccent.success),
      'replacement_requested' => ('Replacement requested', KpiAccent.warning),
      'damaged' => ('Damaged', KpiAccent.warning),
      'available' || 'pending' => ('Pending', KpiAccent.primary),
      _ => (status, KpiAccent.neutral),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

Future<void> _showCreateDistributionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final studentController = TextEditingController();
  final catalogController = TextEditingController();
  final quantityController = TextEditingController(text: '1');

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create distribution'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: QaTestKeys.inventoryDistributionStudentIdField,
              controller: studentController,
              decoration: const InputDecoration(labelText: 'Student ID'),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.inventoryDistributionCatalogItemField,
              controller: catalogController,
              decoration: const InputDecoration(labelText: 'Catalog item ID'),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.inventoryDistributionQuantityField,
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.inventoryDistributionCreateSubmitButton,
          onPressed: () async {
            final qty = int.tryParse(quantityController.text.trim()) ?? 1;
            final result =
                await ref.read(createDistributionProvider.notifier).execute(
                      studentId: studentController.text.trim(),
                      catalogItemId: catalogController.text.trim(),
                      quantity: qty < 1 ? 1 : qty,
                    );
            if (!context.mounted || result == null) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                key: QaTestKeys.inventoryDistributionCreateSuccessSnackbar,
                content: Text('Distribution created.'),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}
