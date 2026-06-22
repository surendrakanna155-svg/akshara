import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_key_value_card.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../../../theme/theme_extensions.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../inventory_finance/inventory_finance_models.dart';
import '../widgets/finance_kpi_row.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_reconciliation_provider.dart';

/// FN-12 — Inventory–finance reconciliation hub (v7.2c).
class FinanceReconciliationScreen extends ConsumerStatefulWidget {
  const FinanceReconciliationScreen({super.key});

  @override
  ConsumerState<FinanceReconciliationScreen> createState() =>
      _FinanceReconciliationScreenState();
}

class _FinanceReconciliationScreenState
    extends ConsumerState<FinanceReconciliationScreen>
    with SingleTickerProviderStateMixin {
  static const _tabLabels = [
    'Overview',
    'Timeline',
    'Goods receipts',
    'Postings',
    'Vendors',
  ];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(financeReconciliationTabProvider.notifier).state =
            FinanceReconciliationTab.values[_tabController.index];
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FinanceModuleScaffold(
      screen: FinanceScreen.reconciliation,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: [for (final label in _tabLabels) Tab(text: label)],
          ),
          const SizedBox(height: AksharaSpacing.s4),
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: const [
                _OverviewTab(),
                _TimelineTab(),
                _GoodsReceiptsTab(),
                _PostingsTab(),
                _VendorsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState =
        ref.watch(financeReconciliationDashboardViewStateProvider);

    return FinanceAsyncBody<InventoryFinanceReconciliationDashboard>(
      state: viewState,
      loadingLabel: 'Loading reconciliation dashboard',
      emptyMessage: 'No inventory–finance data available.',
      emptyIcon: Icons.sync_alt_outlined,
      onRetry: () => retryFinanceReconciliation(ref),
      builder: (data) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinanceKpiRow(
              kpis: [
                FinanceKpi(
                  id: 'open_ap',
                  value: data.openApAmount,
                  label: 'Open AP commitments',
                  icon: Icons.receipt_long_outlined,
                  accentName: 'warning',
                  detail: '${data.openApCommitments} open',
                ),
                FinanceKpi(
                  id: 'inventory_value',
                  value: data.inventoryValue,
                  label: 'Stock valuation',
                  icon: Icons.inventory_2_outlined,
                  accentName: 'primary',
                ),
                FinanceKpi(
                  id: 'postings',
                  value: '${data.postedFinancePostings}',
                  label: 'Finance postings',
                  icon: Icons.account_balance_outlined,
                  accentName: 'success',
                ),
                FinanceKpi(
                  id: 'grns',
                  value: '${data.goodsReceiptCount}',
                  label: 'Goods receipts',
                  icon: Icons.local_shipping_outlined,
                  accentName: 'info',
                ),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s6),
            const AksharaSectionHeader(title: 'Procurement summary'),
            const SizedBox(height: AksharaSpacing.s3),
            _SummaryRow(label: 'Active vendors', value: '${data.vendorCount}'),
            _SummaryRow(
              label: 'Purchase orders',
              value: '${data.purchaseOrderCount}',
            ),
            _SummaryRow(
              label: 'Draft POs pending approval',
              value: '${data.draftPurchaseOrders}',
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTab extends ConsumerWidget {
  const _TimelineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(financeReconciliationTimelineViewStateProvider);

    return FinanceAsyncBody<List<InventoryFinanceTimelineEntry>>(
      state: viewState,
      loadingLabel: 'Loading transaction timeline',
      emptyMessage: 'No inventory–finance events recorded yet.',
      emptyIcon: Icons.timeline_outlined,
      onRetry: () => retryFinanceReconciliation(ref),
      builder: (entries) => ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: context.colors.primaryContainer,
              child: Icon(
                _iconForEvent(entry.eventType),
                color: context.colors.primary,
                size: 18,
              ),
            ),
            title: Text(entry.label),
            subtitle: Text(
              '${entry.eventLabel} · ${_formatDate(entry.occurredAt)}',
            ),
            trailing: entry.amount == null
                ? null
                : Text(
                    entry.amount!,
                    style: context.aksharaText.titleSmall,
                  ),
          );
        },
      ),
    );
  }
}

class _GoodsReceiptsTab extends ConsumerWidget {
  const _GoodsReceiptsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState =
        ref.watch(financeReconciliationGoodsReceiptsViewStateProvider);
    final detailAsync =
        ref.watch(financeReconciliationGoodsReceiptDetailFutureProvider);
    final selectedId = ref.watch(financeSelectedGoodsReceiptIdProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: FinanceAsyncBody(
            state: listState,
            loadingLabel: 'Loading goods receipts',
            emptyMessage: 'No goods receipts posted.',
            emptyIcon: Icons.inventory_outlined,
            onRetry: () => retryFinanceReconciliation(ref),
            builder: (result) => ListView.separated(
              itemCount: result.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final receipt = result.items[index];
                final selected = receipt.id == selectedId;
                return ListTile(
                  selected: selected,
                  title: Text(receipt.grnNumber),
                  subtitle: Text(
                    '${receipt.poNumber} · ${receipt.vendorName}',
                  ),
                  trailing: Text(receipt.status),
                  onTap: () => ref
                      .read(financeSelectedGoodsReceiptIdProvider.notifier)
                      .state = receipt.id,
                );
              },
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 4,
          child: detailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const AksharaEmptyState(
              message: 'Unable to load goods receipt detail.',
              icon: Icons.error_outline,
            ),
            data: (detail) {
              if (detail == null) {
                return const AksharaEmptyState(
                  message: 'Select a goods receipt to review lines.',
                  icon: Icons.fact_check_outlined,
                );
              }
              return _GoodsReceiptDetailPanel(detail: detail);
            },
          ),
        ),
      ],
    );
  }
}

class _GoodsReceiptDetailPanel extends StatelessWidget {
  const _GoodsReceiptDetailPanel({required this.detail});

  final InventoryFinanceGoodsReceiptDetail detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(detail.grnNumber, style: context.aksharaText.titleLarge),
          Text('${detail.poNumber} · ${detail.vendorName}'),
          Text('Received ${_formatDate(detail.receivedAt)} · ${detail.status}'),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Receipt lines'),
          Expanded(
            child: ListView.separated(
              itemCount: detail.lines.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final line = detail.lines[index];
                return ListTile(
                  title: Text(line.sku),
                  subtitle: Text(line.description),
                  trailing: Text('${line.quantityReceived} @ ${line.unitCost}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PostingsTab extends ConsumerWidget {
  const _PostingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(financeReconciliationPostingsViewStateProvider);

    return FinanceAsyncBody(
      state: viewState,
      loadingLabel: 'Loading finance postings',
      emptyMessage: 'No inventory finance postings yet.',
      emptyIcon: Icons.post_add_outlined,
      onRetry: () => retryFinanceReconciliation(ref),
      builder: (result) {
        if (AdminLayout.useCardLayout(context)) {
          return ListView.separated(
            itemCount: result.items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AksharaSpacing.s3),
            itemBuilder: (context, index) {
              final posting = result.items[index];
              return AksharaKeyValueCard(
                title: posting.poNumber,
                entries: [
                  ('Vendor', posting.vendorName),
                  ('AP commitment', posting.commitmentNumber),
                  ('Amount', posting.amount),
                  ('Status', posting.postingStatus),
                  (
                    'Posted',
                    posting.postedAt == null
                        ? '—'
                        : _formatDate(posting.postedAt!),
                  ),
                ],
              );
            },
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('PO')),
              DataColumn(label: Text('Vendor')),
              DataColumn(label: Text('AP commitment')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Posted')),
            ],
            rows: [
              for (final posting in result.items)
                DataRow(cells: [
                  DataCell(Text(posting.poNumber)),
                  DataCell(Text(posting.vendorName)),
                  DataCell(Text(posting.commitmentNumber)),
                  DataCell(Text(posting.amount)),
                  DataCell(Text(posting.postingStatus)),
                  DataCell(Text(
                    posting.postedAt == null
                        ? '—'
                        : _formatDate(posting.postedAt!),
                  )),
                ]),
            ],
          ),
        );
      },
    );
  }
}

class _VendorsTab extends ConsumerWidget {
  const _VendorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsState =
        ref.watch(financeReconciliationVendorsViewStateProvider);
    final transactionsAsync =
        ref.watch(financeReconciliationVendorTransactionsFutureProvider);
    final selectedVendorId = ref.watch(financeSelectedVendorIdProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: FinanceAsyncBody(
            state: vendorsState,
            loadingLabel: 'Loading vendors',
            emptyMessage: 'No inventory vendors registered.',
            emptyIcon: Icons.store_outlined,
            onRetry: () => retryFinanceReconciliation(ref),
            builder: (result) => ListView.separated(
              itemCount: result.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final vendor = result.items[index];
                return ListTile(
                  selected: vendor.id == selectedVendorId,
                  title: Text(vendor.displayName),
                  subtitle: Text('${vendor.vendorCode} · ${vendor.status}'),
                  onTap: () => ref
                      .read(financeSelectedVendorIdProvider.notifier)
                      .state = vendor.id,
                );
              },
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AksharaSectionHeader(title: 'Vendor transaction history'),
                Expanded(
                  child: transactionsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const AksharaEmptyState(
                      message: 'Unable to load vendor transactions.',
                      icon: Icons.error_outline,
                    ),
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        return const AksharaEmptyState(
                          message: 'Select a vendor to view transactions.',
                          icon: Icons.history_outlined,
                        );
                      }
                      return ListView.separated(
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          return ListTile(
                            title: Text(tx.referenceNumber),
                            subtitle: Text(
                              '${tx.typeLabel} · ${_formatDate(tx.occurredAt)}',
                            ),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(tx.amount),
                                Text(tx.status),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: context.aksharaText.titleSmall),
        ],
      ),
    );
  }
}

IconData _iconForEvent(String eventType) {
  return switch (eventType) {
    'purchase_order_created' => Icons.note_add_outlined,
    'purchase_order_approved' => Icons.check_circle_outline,
    'goods_received' => Icons.local_shipping_outlined,
    'finance_posting' => Icons.account_balance_outlined,
    _ => Icons.circle_outlined,
  };
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final month = _monthLabel(local.month);
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} $month ${local.year}, $hour:$minute';
}

String _monthLabel(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}
