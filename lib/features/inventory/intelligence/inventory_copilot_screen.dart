import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../finance/inventory_finance/inventory_finance_models.dart';
import '../inventory_models.dart';
import '../inventory_stock_provider.dart';
import '../widgets/inventory_module_scaffold.dart';
import 'inventory_intelligence_provider.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../theme/spacing.dart';

/// Inventory Copilot — stock forecasting, low-stock prediction, reorder recommendations.
class InventoryCopilotScreen extends ConsumerWidget {
  const InventoryCopilotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(inventoryCopilotProvider);
    final lowStock = ref.watch(inventoryLowStockFutureProvider);

    return InventoryModuleScaffold(
      screen: InventoryScreen.copilot,
      showFilterBar: false,
      body: data.when(
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)),
        data: (snapshot) => ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            _metric('Stock forecast (units)', '${snapshot.stockForecastUnits}'),
            _metric('Confidence', '${snapshot.forecastConfidence}%'),
            if (snapshot.riskAlerts.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...snapshot.riskAlerts.map(
                (a) => AksharaWarningBanner(message: '${a.title}: ${a.detail}'),
              ),
            ],
            const Divider(height: 32),
            const Text('Stock trend', style: TextStyle(fontWeight: FontWeight.bold)),
            ...snapshot.stockTrend.map(
              (t) => Card(
                elevation: 0,
                child: ListTile(
                  title: Text(t.month),
                  subtitle: Text('Forecast ${t.forecast} units'),
                  trailing: Text('${t.consumption} consumed'),
                ),
              ),
            ),
            const Divider(height: 32),
            const Text('Low-stock predictions', style: TextStyle(fontWeight: FontWeight.bold)),
            ...snapshot.lowStockPredictions.map(
              (p) => Card(
                elevation: 0,
                child: ListTile(
                  title: Text(p.itemName),
                  subtitle: Text(
                    '${p.currentStock} units · ${p.predictedDaysUntilStockout}d to stockout',
                  ),
                  trailing: Text('Risk ${p.riskScore}'),
                ),
              ),
            ),
            const Divider(height: 32),
            const Text('Reorder recommendations', style: TextStyle(fontWeight: FontWeight.bold)),
            ...snapshot.reorderRecommendations.map(
              (r) => Card(
                elevation: 0,
                child: ListTile(
                  title: Text(r.itemName),
                  subtitle: Text('${r.recommendedQuantity} units · ${r.urgency} urgency'),
                  trailing: Tooltip(message: r.reason, child: const Icon(Icons.info_outline)),
                ),
              ),
            ),
            const Divider(height: 32),
            const Text('Low stock — raise PO',
                style: TextStyle(fontWeight: FontWeight.bold)),
            lowStock.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(aksharaErrorMessage(e)),
              data: (rows) => rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('All items are above their reorder level.'),
                    )
                  : Column(
                      children: [
                        for (final row in rows)
                          _LowStockRecommendationCard(row: row),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// INV-4 — a copilot low-stock recommendation row with a Raise-PO action that
/// calls the EXISTING createPurchaseOrder against the row's
/// sku + recommendedQuantity + vendorId.
class _LowStockRecommendationCard extends ConsumerWidget {
  const _LowStockRecommendationCard({required this.row});

  final LowStockRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(row.itemName),
        subtitle: Text(
          '${row.sku} · ${row.quantityOnHand}/${row.reorderLevel} · '
          'recommend ${row.recommendedQuantity}',
        ),
        trailing: AksharaManageAction(
          permission: Permission.createInventoryPo,
          auditRoute: RouteNames.inventoryCopilot,
          child: FilledButton.tonal(
            key: QaTestKeys.inventoryLowStockRaisePoButton(row.sku),
            onPressed: () => _raisePo(context, ref),
            child: const Text('Raise PO'),
          ),
        ),
      ),
    );
  }

  Future<void> _raisePo(BuildContext context, WidgetRef ref) async {
    try {
      final po =
          await ref.read(raisePoFromLowStockProvider.notifier).execute(row);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.inventoryLowStockRaisePoSuccessSnackbar,
          content: Text(
            'Draft PO ${po.poNumber} raised for ${row.sku} '
            '(${row.recommendedQuantity} units)',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(error))),
      );
    }
  }
}

Widget _metric(String label, String value) {
  return Card(
    elevation: 0,
    child: ListTile(
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    ),
  );
}
