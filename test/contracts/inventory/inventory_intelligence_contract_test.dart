import 'package:akshara_erp/core/repositories/mock/mock_inventory_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/inventory/intelligence/inventory_intelligence_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;
  final repo = MockInventoryRepository();

  test('inventory copilot returns forecast and reorder recommendations', () async {
    final data = await repo.getInventoryCopilot(query: query);
    expect(data.stockForecastUnits, greaterThan(0));
    expect(data.lowStockPredictions, isNotEmpty);
    expect(data.reorderRecommendations, isNotEmpty);
    expect(data.stockTrend, isNotEmpty);
  });

  test('asset lifecycle returns events and counts', () async {
    final data = await repo.getAssetLifecycle(query: query);
    expect(data.recentEvents, isNotEmpty);
    expect(data.assetsTracked, greaterThan(0));
    expect(data.eventCounts[AssetLifecycleEventType.distribution], greaterThan(0));
  });

  test('procurement workflow returns pending approvals', () async {
    final data = await repo.getProcurementWorkflow(query: query);
    expect(data.pendingApprovals, greaterThanOrEqualTo(0));
    expect(data.recommendations, isNotEmpty);
  });

  test('record asset lifecycle event returns created event', () async {
    final event = await repo.recordAssetLifecycleEvent(
      query: query,
      request: const RecordAssetLifecycleEventRequest(
        assetId: 'asset_1',
        eventType: AssetLifecycleEventType.purchase,
        assetTag: 'INV-AST-1042',
        notes: 'Initial procurement',
      ),
    );
    expect(event.assetId, 'asset_1');
    expect(event.eventType, AssetLifecycleEventType.purchase);
  });
}
