import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../phase4/phase4_providers.dart';
import 'inventory_distribution_models.dart';
import 'inventory_distribution_mutations_provider.dart';

class InventoryReplacementScreen extends ConsumerWidget {
  const InventoryReplacementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(inventoryReplacementRequestsProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        key: QaTestKeys.inventoryReplacementScreen,
        appBar: AppBar(
          title: const Text('Replacement Workflow'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Fulfilled'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: requests.when(
          data: (items) => TabBarView(
            children: [
              _RequestList(requests: _filter(items, 'pending')),
              _RequestList(requests: _filter(items, 'approved')),
              _RequestList(requests: _filter(items, 'fulfilled')),
              _RequestList(requests: _filter(items, 'rejected')),
            ],
          ),
          loading: () => const AksharaLoadingState(),
          error: (e, _) => AksharaErrorState(
            message: 'Could not load replacement requests: $e',
            onRetry: () => ref.invalidate(inventoryReplacementRequestsProvider),
          ),
        ),
      ),
    );
  }

  List<InvReplacementRequest> _filter(
    List<InvReplacementRequest> items,
    String status,
  ) =>
      items.where((r) => r.status == status).toList();
}

class _RequestList extends ConsumerWidget {
  const _RequestList({required this.requests});

  final List<InvReplacementRequest> requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) {
      return const AksharaEmptyState(
        message: 'No replacement requests in this state.',
        icon: Icons.swap_horiz_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: AksharaSpacing.s3),
      itemBuilder: (context, index) {
        final request = requests[index];
        return _ReplacementCard(request: request);
      },
    );
  }
}

class _ReplacementCard extends ConsumerWidget {
  const _ReplacementCard({required this.request});

  final InvReplacementRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: QaTestKeys.inventoryReplacementRow(request.id),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.itemName ?? request.distributionId,
                    style: context.aksharaText.titleMedium,
                  ),
                ),
                Chip(label: Text(request.status)),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Text('Student: ${request.studentId}'),
            if (request.category != null) Text('Category: ${request.category}'),
            Text('Qty: ${request.quantity}'),
            if (request.notes != null && request.notes!.isNotEmpty)
              Text(
                request.notes!,
                style: context.aksharaText.bodySmall.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            if (request.rejectionReason != null)
              Text(
                'Reason: ${request.rejectionReason}',
                style: TextStyle(color: context.colors.error),
              ),
            const SizedBox(height: AksharaSpacing.s3),
            _ActionRow(request: request),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.request});

  final InvReplacementRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AksharaSpacing.s2,
      children: [
        if (request.status == 'pending')
          AksharaManageAction(
            permission: Permission.manageInventoryDistribution,
            child: FilledButton(
              key: QaTestKeys.inventoryReplacementApproveButton(request.id),
              onPressed: () => _approve(context, ref),
              child: const Text('Approve'),
            ),
          ),
        if (request.status == 'approved')
          AksharaManageAction(
            permission: Permission.manageInventoryDistribution,
            child: FilledButton(
              key: QaTestKeys.inventoryReplacementFulfillButton(request.id),
              onPressed: () => _fulfill(context, ref),
              child: const Text('Fulfill'),
            ),
          ),
        if (request.status == 'pending' || request.status == 'approved')
          AksharaManageAction(
            permission: Permission.manageInventoryDistribution,
            child: OutlinedButton(
              key: QaTestKeys.inventoryReplacementRejectButton(request.id),
              onPressed: () => _reject(context, ref),
              child: const Text('Reject'),
            ),
          ),
      ],
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(approveReplacementProvider.notifier)
        .execute(requestId: request.id);
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.inventoryReplacementApproveSuccessSnackbar,
        content: Text('Replacement ${request.id} approved'),
      ),
    );
  }

  Future<void> _fulfill(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(fulfillReplacementProvider.notifier)
        .execute(requestId: request.id);
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.inventoryReplacementFulfillSuccessSnackbar,
        content: Text('Replacement ${request.id} fulfilled'),
      ),
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(rejectReplacementProvider.notifier).execute(
          requestId: request.id,
          reason: 'Not eligible for replacement',
        );
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.inventoryReplacementRejectSuccessSnackbar,
        content: Text('Replacement ${request.id} rejected'),
      ),
    );
  }
}
