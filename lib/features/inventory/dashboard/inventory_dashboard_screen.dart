import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../router/route_names.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../inventory_models.dart';
import '../inventory_providers.dart';
import '../widgets/inventory_kpi_row.dart';
import '../widgets/inventory_module_scaffold.dart';

/// INV-01 — Inventory Dashboard.
class InventoryDashboardScreen extends ConsumerWidget {
  const InventoryDashboardScreen({super.key});

  static const List<String> filterLabels = [
    'All departments',
    'IT',
    'Hostel',
    'Science',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(inventoryDashboardViewStateProvider);
    final filterIndex = ref.watch(inventoryDashboardFilterProvider);

    return InventoryModuleScaffold(
      screen: InventoryScreen.dashboard,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(inventoryDashboardFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageInventory,
        child: OutlinedButton.icon(
          onPressed: () => showAksharaExportQueuedSnackBar(context),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
        ),
      ),
      body: ErpAsyncBody<InventoryDashboardData>(
        state: viewState,
        loadingLabel: 'Loading inventory dashboard',
        emptyMessage: 'No inventory data for the selected department.',
        emptyIcon: Icons.inventory_2_outlined,
        onRetry: () => retryErpFuture(ref, inventoryDashboardFutureProvider),
        builder: (data) => _buildDashboardContent(context, data),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    InventoryDashboardData data,
  ) {
    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.stockAlerts.isNotEmpty)
          AksharaWarningBanner(
            message:
                '${data.stockAlerts.length} items below reorder level — ${data.stockAlerts.first.itemName} (${data.stockAlerts.first.currentStock} left)',
            actionLabel: 'View procurement',
            onAction: () => context.go(RouteNames.inventoryProcurement),
          ),
        if (data.stockAlerts.isNotEmpty)
          const SizedBox(height: AksharaSpacing.s4),
        InventoryKpiRow(kpis: data.kpis, desktopColumns: 3),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Recent activity'),
        const SizedBox(height: AksharaSpacing.s3),
        _ActivityList(items: data.recentActivity),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          _StockAlertsCard(alerts: data.stockAlerts),
          const SizedBox(height: AksharaSpacing.s4),
          _IntegrationLinksCard(links: data.integrationLinks),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _StockAlertsCard(alerts: data.stockAlerts)),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: _IntegrationLinksCard(links: data.integrationLinks),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'Open Finance',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI inventory insight',
          onAction: () => context.go(RouteNames.financeDashboard),
        ),
      ],
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.items});

  final List<InventoryActivityItem> items;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final item in items) ...[
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description, style: text.bodyMedium),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      '${item.actor} · ${item.timestamp}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Recent activity, ${items.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Activity')),
              DataColumn(label: Text('Actor')),
              DataColumn(label: Text('Time')),
              DataColumn(label: Text('Module')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  cells: [
                    DataCell(Text(item.description)),
                    DataCell(Text(item.actor)),
                    DataCell(Text(item.timestamp)),
                    DataCell(Text(item.moduleLink)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockAlertsCard extends StatelessWidget {
  const _StockAlertsCard({required this.alerts});

  final List<InventoryStockAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      container: true,
      label: 'Low stock alerts, ${alerts.length} items',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AksharaSectionHeader(title: 'Low stock alerts'),
              const SizedBox(height: AksharaSpacing.s3),
              for (final alert in alerts) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(alert.itemName, style: text.bodyMedium),
                    ),
                    Text(
                      '${alert.currentStock}/${alert.reorderLevel}',
                      style: text.titleSmall.copyWith(color: colors.error),
                    ),
                  ],
                ),
                Text(
                  '${alert.category} · ${alert.department}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IntegrationLinksCard extends StatelessWidget {
  const _IntegrationLinksCard({required this.links});

  final List<String> links;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Module integrations, ${links.length} links',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AksharaSectionHeader(title: 'Module integrations'),
              const SizedBox(height: AksharaSpacing.s3),
              for (final link in links) ...[
                Row(
                  children: [
                    const Icon(Icons.link_outlined, size: 18),
                    const SizedBox(width: AksharaSpacing.s2),
                    Expanded(child: Text(link, style: text.bodyMedium)),
                  ],
                ),
                const SizedBox(height: AksharaSpacing.s2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
