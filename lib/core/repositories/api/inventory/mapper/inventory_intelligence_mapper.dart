import '../../../../../features/inventory/intelligence/inventory_intelligence_models.dart';

class InventoryIntelligenceMapper {
  const InventoryIntelligenceMapper();

  InventoryCopilotData toCopilot(Map<String, dynamic> json) {
    return InventoryCopilotData(
      stockForecastUnits: _int(json['stockForecastUnits'] ?? json['stock_forecast_units']),
      forecastConfidence: _int(json['forecastConfidence'] ?? json['forecast_confidence']),
      lowStockPredictions: _lowStock(json['lowStockPredictions'] ?? json['low_stock_predictions']),
      reorderRecommendations: _reorder(json['reorderRecommendations'] ?? json['reorder_recommendations']),
      stockTrend: _trend(json['stockTrend'] ?? json['stock_trend']),
      riskAlerts: _alerts(json['riskAlerts'] ?? json['risk_alerts']),
      generatedAt: json['generatedAt'] as String? ?? json['generated_at'] as String? ?? '',
    );
  }

  AssetLifecycleData toLifecycle(Map<String, dynamic> json) {
    return AssetLifecycleData(
      recentEvents: _events(json['recentEvents'] ?? json['recent_events']),
      eventCounts: _eventCounts(json['eventCounts'] ?? json['event_counts']),
      assetsTracked: _int(json['assetsTracked'] ?? json['assets_tracked']),
      generatedAt: json['generatedAt'] as String? ?? json['generated_at'] as String? ?? '',
    );
  }

  ProcurementWorkflowData toProcurementWorkflow(Map<String, dynamic> json) {
    return ProcurementWorkflowData(
      pendingApprovals: _int(json['pendingApprovals'] ?? json['pending_approvals']),
      overdueDeliveries: _int(json['overdueDeliveries'] ?? json['overdue_deliveries']),
      alerts: _procAlerts(json['alerts']),
      recommendations: _procRecs(json['recommendations']),
      generatedAt: json['generatedAt'] as String? ?? json['generated_at'] as String? ?? '',
    );
  }

  AssetLifecycleEvent toLifecycleEvent(Map<String, dynamic> json) {
    return AssetLifecycleEvent(
      id: json['id'] as String? ?? '',
      assetId: json['assetId'] as String? ?? json['asset_id'] as String? ?? '',
      assetTag: json['assetTag'] as String? ?? json['asset_tag'] as String? ?? '',
      eventType: _eventType(json['eventType'] ?? json['event_type']),
      notes: json['notes'] as String? ?? '',
      recordedAt: json['recordedAt'] as String? ?? json['recorded_at'] as String? ?? '',
      recordedBy: json['recordedBy'] as String? ?? json['recorded_by'] as String?,
    );
  }

  List<InventoryLowStockPrediction> _lowStock(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return InventoryLowStockPrediction(
        sku: m['sku'] as String? ?? '',
        itemName: m['itemName'] as String? ?? m['item_name'] as String? ?? '',
        currentStock: _int(m['currentStock'] ?? m['current_stock']),
        predictedDaysUntilStockout: _int(
          m['predictedDaysUntilStockout'] ?? m['predicted_days_until_stockout'],
        ),
        riskScore: _int(m['riskScore'] ?? m['risk_score']),
      );
    }).toList();
  }

  List<InventoryReorderRecommendation> _reorder(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return InventoryReorderRecommendation(
        id: m['id'] as String? ?? '',
        sku: m['sku'] as String? ?? '',
        itemName: m['itemName'] as String? ?? m['item_name'] as String? ?? '',
        recommendedQuantity: _int(m['recommendedQuantity'] ?? m['recommended_quantity']),
        urgency: m['urgency'] as String? ?? 'low',
        reason: m['reason'] as String? ?? '',
      );
    }).toList();
  }

  List<InventoryStockTrendPoint> _trend(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return InventoryStockTrendPoint(
        month: m['month'] as String? ?? '',
        consumption: _int(m['consumption']),
        forecast: _int(m['forecast']),
      );
    }).toList();
  }

  List<InventoryRiskAlert> _alerts(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return InventoryRiskAlert(
        id: m['id'] as String? ?? '',
        severity: m['severity'] as String? ?? 'low',
        title: m['title'] as String? ?? '',
        detail: m['detail'] as String? ?? '',
      );
    }).toList();
  }

  List<AssetLifecycleEvent> _events(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => toLifecycleEvent(Map<String, dynamic>.from(e as Map))).toList();
  }

  Map<AssetLifecycleEventType, int> _eventCounts(dynamic raw) {
    final counts = {
      for (final type in AssetLifecycleEventType.values) type: 0,
    };
    if (raw is Map) {
      for (final entry in raw.entries) {
        final type = _eventType(entry.key);
        counts[type] = _int(entry.value);
      }
    }
    return counts;
  }

  List<ProcurementWorkflowAlert> _procAlerts(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return ProcurementWorkflowAlert(
        id: m['id'] as String? ?? '',
        poNumber: m['poNumber'] as String? ?? m['po_number'] as String? ?? '',
        severity: m['severity'] as String? ?? 'low',
        title: m['title'] as String? ?? '',
        detail: m['detail'] as String? ?? '',
      );
    }).toList();
  }

  List<ProcurementWorkflowRecommendation> _procRecs(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return ProcurementWorkflowRecommendation(
        id: m['id'] as String? ?? '',
        poNumber: m['poNumber'] as String? ?? m['po_number'] as String? ?? '',
        action: m['action'] as String? ?? '',
        priority: m['priority'] as String? ?? 'low',
      );
    }).toList();
  }

  AssetLifecycleEventType _eventType(dynamic value) {
    final raw = '$value';
    return AssetLifecycleEventType.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => AssetLifecycleEventType.purchase,
    );
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? 0;
  }
}
