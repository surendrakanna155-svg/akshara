import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'inventory_intelligence_models.dart';

final inventoryCopilotProvider = FutureProvider<InventoryCopilotData>((ref) async {
  return ref.read(inventoryRepositoryProvider).getInventoryCopilot(
        query: ref.watch(repositoryQueryProvider),
      );
});

final assetLifecycleProvider = FutureProvider<AssetLifecycleData>((ref) async {
  return ref.read(inventoryRepositoryProvider).getAssetLifecycle(
        query: ref.watch(repositoryQueryProvider),
      );
});

final procurementWorkflowProvider = FutureProvider<ProcurementWorkflowData>((ref) async {
  return ref.read(inventoryRepositoryProvider).getProcurementWorkflow(
        query: ref.watch(repositoryQueryProvider),
      );
});
