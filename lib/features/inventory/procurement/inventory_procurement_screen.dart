import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../inventory_models.dart';
import '../inventory_providers.dart';
import '../inventory_workflow_actions.dart';
import '../widgets/inventory_module_scaffold.dart';

/// INV-06 — Procurement.
class InventoryProcurementScreen extends ConsumerWidget {
  const InventoryProcurementScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Draft',
    'Ordered',
    'Received',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(inventoryProcurementLoadingProvider);
    final isError = ref.watch(inventoryProcurementErrorProvider);
    final isEmpty = ref.watch(inventoryProcurementEmptyProvider);
    final orders = ref.watch(inventoryFilteredProcurementProvider);
    final filterIndex = ref.watch(inventoryProcurementFilterProvider);
    final pageResult = ref.watch(inventoryProcurementPageResultProvider);

    return InventoryModuleScaffold(
      screen: InventoryScreen.procurement,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(inventoryProcurementFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageInventory,
        child: OutlinedButton.icon(
          onPressed: () => context.go(RouteNames.financeDashboard),
          icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
          label: const Text('Finance POs'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: AksharaManageAction(
              permission: Permission.manageInventory,
              child: FilledButton.icon(
                key: QaTestKeys.inventoryCreatePoButton,
                onPressed: () => showCreateProcurementOrderDialog(context, ref),
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                label: const Text('Create PO'),
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          _buildBody(
            context,
            isLoading: isLoading,
            isError: isError,
            isEmpty: isEmpty,
            orders: orders,
            pageResult: pageResult,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<InventoryProcurementOrder> orders,
    required PaginatedResult<InventoryProcurementOrder>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading procurement orders',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load procurement orders.',
      );
    }

    if (isEmpty || orders.isEmpty) {
      return const AksharaEmptyState(
        message: 'No procurement orders match the selected filters.',
        icon: Icons.shopping_cart_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Purchase orders'),
        const SizedBox(height: AksharaSpacing.s3),
        _ProcurementTable(orders: orders),
        AksharaPaginatedListFooter<InventoryProcurementOrder>(
          result: pageResult,
          pageProvider: inventoryProcurementPageProvider,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Each PO maps to a Finance purchase order (FN-PO-*). Library and Hostel procurement requests appear as draft POs.',
          actionLabel: 'View vendors',
          icon: Icons.store_outlined,
          semanticLabelPrefix: 'Procurement integration',
          onAction: () => context.go(RouteNames.inventoryVendors),
        ),
      ],
    );
  }
}

class _ProcurementTable extends ConsumerWidget {
  const _ProcurementTable({required this.orders});

  final List<InventoryProcurementOrder> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final order in orders) ...[
            _ProcurementCard(order: order),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Purchase orders, ${orders.length} orders',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('PO Number')),
              DataColumn(label: Text('Vendor')),
              DataColumn(label: Text('Items')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Delivery')),
              DataColumn(label: Text('Finance PO')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final order in orders)
                DataRow(
                  cells: [
                    DataCell(Text(order.poNumber)),
                    DataCell(Text(order.vendorName)),
                    DataCell(Text(order.items)),
                    DataCell(Text(order.totalAmount)),
                    DataCell(Text(order.expectedDelivery)),
                    DataCell(Text(order.financePoId)),
                    DataCell(_ProcurementStatusChip(status: order.status)),
                    DataCell(_ProcurementReceiveAction(order: order)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcurementReceiveAction extends ConsumerWidget {
  const _ProcurementReceiveAction({required this.order});

  final InventoryProcurementOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (order.status != InventoryProcurementStatus.ordered) {
      return const SizedBox.shrink();
    }

    return AksharaManageAction(
      permission: Permission.manageInventory,
      child: TextButton(
        key: QaTestKeys.inventoryPoReceiveHandoffButton(order.id),
        onPressed: () => submitProcurementReceiveHandoff(context, ref, order),
        child: const Text('Record receipt'),
      ),
    );
  }
}

class _ProcurementCard extends ConsumerWidget {
  const _ProcurementCard({required this.order});

  final InventoryProcurementOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Purchase order ${order.poNumber}, ${order.vendorName}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${order.poNumber} — ${order.vendorName}', style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(order.items, style: text.bodyMedium),
              Text(
                '${order.totalAmount} · ${order.financePoId}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _ProcurementStatusChip(status: order.status),
              if (order.status == InventoryProcurementStatus.ordered) ...[
                const SizedBox(height: AksharaSpacing.s2),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ProcurementReceiveAction(order: order),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcurementStatusChip extends StatelessWidget {
  const _ProcurementStatusChip({required this.status});

  final InventoryProcurementStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      InventoryProcurementStatus.draft => ('Draft', KpiAccent.neutral),
      InventoryProcurementStatus.ordered => ('Ordered', KpiAccent.primary),
      InventoryProcurementStatus.received => ('Received', KpiAccent.success),
      InventoryProcurementStatus.cancelled => ('Cancelled', KpiAccent.error),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'PO status: $label',
    );
  }
}
