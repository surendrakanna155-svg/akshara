import 'package:flutter/foundation.dart';

@immutable
class InventoryCopilotData {
  const InventoryCopilotData({
    required this.stockForecastUnits,
    required this.forecastConfidence,
    required this.lowStockPredictions,
    required this.reorderRecommendations,
    required this.stockTrend,
    required this.riskAlerts,
    required this.generatedAt,
  });

  final int stockForecastUnits;
  final int forecastConfidence;
  final List<InventoryLowStockPrediction> lowStockPredictions;
  final List<InventoryReorderRecommendation> reorderRecommendations;
  final List<InventoryStockTrendPoint> stockTrend;
  final List<InventoryRiskAlert> riskAlerts;
  final String generatedAt;
}

@immutable
class InventoryLowStockPrediction {
  const InventoryLowStockPrediction({
    required this.sku,
    required this.itemName,
    required this.currentStock,
    required this.predictedDaysUntilStockout,
    required this.riskScore,
  });

  final String sku;
  final String itemName;
  final int currentStock;
  final int predictedDaysUntilStockout;
  final int riskScore;
}

@immutable
class InventoryReorderRecommendation {
  const InventoryReorderRecommendation({
    required this.id,
    required this.sku,
    required this.itemName,
    required this.recommendedQuantity,
    required this.urgency,
    required this.reason,
  });

  final String id;
  final String sku;
  final String itemName;
  final int recommendedQuantity;
  final String urgency;
  final String reason;
}

@immutable
class InventoryStockTrendPoint {
  const InventoryStockTrendPoint({
    required this.month,
    required this.consumption,
    required this.forecast,
  });

  final String month;
  final int consumption;
  final int forecast;
}

@immutable
class InventoryRiskAlert {
  const InventoryRiskAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.detail,
  });

  final String id;
  final String severity;
  final String title;
  final String detail;
}

enum AssetLifecycleEventType {
  purchase,
  distribution,
  replacement,
  damage,
  retirement;

  String get label => switch (this) {
        AssetLifecycleEventType.purchase => 'Purchase',
        AssetLifecycleEventType.distribution => 'Distribution',
        AssetLifecycleEventType.replacement => 'Replacement',
        AssetLifecycleEventType.damage => 'Damage',
        AssetLifecycleEventType.retirement => 'Retirement',
      };
}

@immutable
class AssetLifecycleEvent {
  const AssetLifecycleEvent({
    required this.id,
    required this.assetId,
    required this.assetTag,
    required this.eventType,
    required this.notes,
    required this.recordedAt,
    required this.recordedBy,
  });

  final String id;
  final String assetId;
  final String assetTag;
  final AssetLifecycleEventType eventType;
  final String notes;
  final String recordedAt;
  final String? recordedBy;
}

@immutable
class AssetLifecycleData {
  const AssetLifecycleData({
    required this.recentEvents,
    required this.eventCounts,
    required this.assetsTracked,
    required this.generatedAt,
  });

  final List<AssetLifecycleEvent> recentEvents;
  final Map<AssetLifecycleEventType, int> eventCounts;
  final int assetsTracked;
  final String generatedAt;
}

@immutable
class ProcurementWorkflowData {
  const ProcurementWorkflowData({
    required this.pendingApprovals,
    required this.overdueDeliveries,
    required this.alerts,
    required this.recommendations,
    required this.generatedAt,
  });

  final int pendingApprovals;
  final int overdueDeliveries;
  final List<ProcurementWorkflowAlert> alerts;
  final List<ProcurementWorkflowRecommendation> recommendations;
  final String generatedAt;
}

@immutable
class ProcurementWorkflowAlert {
  const ProcurementWorkflowAlert({
    required this.id,
    required this.poNumber,
    required this.severity,
    required this.title,
    required this.detail,
  });

  final String id;
  final String poNumber;
  final String severity;
  final String title;
  final String detail;
}

@immutable
class ProcurementWorkflowRecommendation {
  const ProcurementWorkflowRecommendation({
    required this.id,
    required this.poNumber,
    required this.action,
    required this.priority,
  });

  final String id;
  final String poNumber;
  final String action;
  final String priority;
}

@immutable
class RecordAssetLifecycleEventRequest {
  const RecordAssetLifecycleEventRequest({
    required this.assetId,
    required this.eventType,
    this.assetTag,
    this.notes,
  });

  final String assetId;
  final AssetLifecycleEventType eventType;
  final String? assetTag;
  final String? notes;
}
