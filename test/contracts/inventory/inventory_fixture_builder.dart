import 'package:akshara_erp/core/repositories/api/inventory/dto/inventory_enum_codec.dart';
import 'package:akshara_erp/features/inventory/inventory_models.dart';

/// Builds API-shaped JSON envelopes from Inventory domain models for contract tests.
class InventoryFixtureBuilder {
  const InventoryFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> trendPoint(InventoryTrendPoint point) => {
        'label': point.label,
        'amountLakhs': point.amountLakhs,
        'targetLakhs': point.targetLakhs,
      };

  Map<String, dynamic> segment(InventorySegment segment) => {
        'label': segment.label,
        'value': segment.value,
        'percent': segment.percent,
      };

  Map<String, dynamic> assetItem(InventoryAsset asset) => {
        'id': asset.id,
        'assetTag': asset.assetTag,
        'name': asset.name,
        'category': asset.category,
        'location': asset.location,
        'purchaseDate': asset.purchaseDate,
        'value': asset.value,
        'status': InventoryEnumCodec.assetStatusToApi(asset.status),
        if (asset.assignedTo != null) 'assignedTo': asset.assignedTo,
        'financeAssetId': asset.financeAssetId,
        'lastAudit': asset.lastAudit,
      };

  Map<String, dynamic> categoryItem(InventoryCategory category) => {
        'id': category.id,
        'name': category.name,
        'type': InventoryEnumCodec.categoryTypeToApi(category.type),
        'assetCount': category.assetCount,
        'totalValue': category.totalValue,
        'depreciationRate': category.depreciationRate,
        'responsibleDept': category.responsibleDept,
        'description': category.description,
      };

  Map<String, dynamic> allocationItem(InventoryAllocation allocation) => {
        'id': allocation.id,
        'assetTag': allocation.assetTag,
        'assetName': allocation.assetName,
        'department': allocation.department,
        'assignedTo': allocation.assignedTo,
        'assignedDate': allocation.assignedDate,
        'returnDue': allocation.returnDue,
        'status': InventoryEnumCodec.allocationStatusToApi(allocation.status),
        if (allocation.hrEmployeeId != null)
          'hrEmployeeId': allocation.hrEmployeeId,
        if (allocation.hostelBlock != null) 'hostelBlock': allocation.hostelBlock,
        if (allocation.librarySection != null)
          'librarySection': allocation.librarySection,
        'integrationNote': allocation.integrationNote,
      };

  Map<String, dynamic> maintenanceItem(InventoryMaintenanceRecord record) => {
        'id': record.id,
        'assetTag': record.assetTag,
        'assetName': record.assetName,
        'maintenanceType': record.maintenanceType,
        'scheduledDate': record.scheduledDate,
        'technician': record.technician,
        'hrTechnicianId': record.hrTechnicianId,
        'estimatedCost': record.estimatedCost,
        'status': InventoryEnumCodec.maintenanceStatusToApi(record.status),
        'financeBudgetCode': record.financeBudgetCode,
      };

  Map<String, dynamic> procurementItem(InventoryProcurementOrder order) => {
        'id': order.id,
        'poNumber': order.poNumber,
        'vendorName': order.vendorName,
        'items': order.items,
        'totalAmount': order.totalAmount,
        'orderDate': order.orderDate,
        'expectedDelivery': order.expectedDelivery,
        'status': InventoryEnumCodec.procurementStatusToApi(order.status),
        'financePoId': order.financePoId,
        'requestedBy': order.requestedBy,
      };

  Map<String, dynamic> vendorItem(InventoryVendor vendor) => {
        'id': vendor.id,
        'name': vendor.name,
        'category': vendor.category,
        'contactPerson': vendor.contactPerson,
        'phone': vendor.phone,
        'email': vendor.email,
        'gstNumber': vendor.gstNumber,
        'activeOrders': vendor.activeOrders,
        'totalSpend': vendor.totalSpend,
        'status': InventoryEnumCodec.vendorStatusToApi(vendor.status),
        'financeVendorId': vendor.financeVendorId,
      };

  Map<String, dynamic> dashboardEnvelope(InventoryDashboardData data) {
    return envelope({
      'aiInsight': data.aiInsight,
      'integrationLinks': data.integrationLinks,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'recentActivity': [
        for (final activity in data.recentActivity)
          {
            'id': activity.id,
            'description': activity.description,
            'timestamp': activity.timestamp,
            'actor': activity.actor,
            'moduleLink': activity.moduleLink,
          },
      ],
      'stockAlerts': [
        for (final alert in data.stockAlerts)
          {
            'id': alert.id,
            'itemName': alert.itemName,
            'category': alert.category,
            'currentStock': alert.currentStock,
            'reorderLevel': alert.reorderLevel,
            'department': alert.department,
          },
      ],
    });
  }

  Map<String, dynamic> assetsEnvelope(List<InventoryAsset> assets) {
    return listEnvelope([for (final asset in assets) assetItem(asset)]);
  }

  Map<String, dynamic> categoriesEnvelope(List<InventoryCategory> categories) {
    return listEnvelope([
      for (final category in categories) categoryItem(category),
    ]);
  }

  Map<String, dynamic> allocationsEnvelope(List<InventoryAllocation> allocations) {
    return listEnvelope([
      for (final allocation in allocations) allocationItem(allocation),
    ]);
  }

  Map<String, dynamic> maintenanceEnvelope(
    List<InventoryMaintenanceRecord> records,
  ) {
    return listEnvelope([
      for (final record in records) maintenanceItem(record),
    ]);
  }

  Map<String, dynamic> procurementEnvelope(
    List<InventoryProcurementOrder> orders,
  ) {
    return listEnvelope([
      for (final order in orders) procurementItem(order),
    ]);
  }

  Map<String, dynamic> vendorsEnvelope(List<InventoryVendor> vendors) {
    return listEnvelope([for (final vendor in vendors) vendorItem(vendor)]);
  }

  Map<String, dynamic> reportsEnvelope(InventoryReportsData data) {
    return envelope({
      'catalog': [
        for (final item in data.catalog)
          {
            'id': item.id,
            'title': item.title,
            'description': item.description,
            'lastGenerated': item.lastGenerated,
          },
      ],
      'assetValueTrend': [
        for (final point in data.assetValueTrend) trendPoint(point),
      ],
      'allocationByDept': [
        for (final segment in data.allocationByDept) this.segment(segment),
      ],
      'procurementTrend': [
        for (final point in data.procurementTrend) trendPoint(point),
      ],
    });
  }
}
