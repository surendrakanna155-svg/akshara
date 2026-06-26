import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../inventory_models.dart';
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
          ],
        ),
      ),
    );
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
