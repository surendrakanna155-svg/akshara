import 'package:flutter/material.dart';

/// Inventory sub-module destinations (INV-01 → INV-08).
enum InventoryScreen {
  dashboard,
  assets,
  categories,
  allocation,
  maintenance,
  procurement,
  vendors,
  reports,
  copilot,
  lifecycle;

  String get label => switch (this) {
        InventoryScreen.dashboard => 'Dashboard',
        InventoryScreen.assets => 'Assets',
        InventoryScreen.categories => 'Categories',
        InventoryScreen.allocation => 'Allocation',
        InventoryScreen.maintenance => 'Maintenance',
        InventoryScreen.procurement => 'Procurement',
        InventoryScreen.vendors => 'Vendors',
        InventoryScreen.reports => 'Reports',
        InventoryScreen.copilot => 'Inventory Copilot',
        InventoryScreen.lifecycle => 'Asset Lifecycle',
      };
}

enum InventoryAssetStatus { available, allocated, maintenance, retired }

enum InventoryCategoryType {
  equipment,
  furniture,
  electronics,
  consumable,
  lab,
  sports,
}

enum InventoryAllocationStatus { active, pendingReturn, overdue }

enum InventoryMaintenanceStatus { scheduled, inProgress, completed, overdue }

enum InventoryProcurementStatus { draft, ordered, received, cancelled }

enum InventoryVendorStatus { active, pending, inactive }

@immutable
class InventoryKpi {
  const InventoryKpi({
    required this.id,
    required this.value,
    required this.label,
    required this.icon,
    required this.accentName,
    this.detail,
  });

  final String id;
  final String value;
  final String label;
  final IconData icon;
  final String accentName;
  final String? detail;
}

@immutable
class InventoryTrendPoint {
  const InventoryTrendPoint({
    required this.label,
    required this.amountLakhs,
    required this.targetLakhs,
  });

  final String label;
  final double amountLakhs;
  final double targetLakhs;
}

@immutable
class InventorySegment {
  const InventorySegment({
    required this.label,
    required this.value,
    required this.percent,
  });

  final String label;
  final double value;
  final double percent;
}

@immutable
class InventoryAsset {
  const InventoryAsset({
    required this.id,
    required this.assetTag,
    required this.name,
    required this.category,
    required this.location,
    required this.purchaseDate,
    required this.value,
    required this.status,
    required this.assignedTo,
    required this.financeAssetId,
    required this.lastAudit,
  });

  final String id;
  final String assetTag;
  final String name;
  final String category;
  final String location;
  final String purchaseDate;
  final String value;
  final InventoryAssetStatus status;
  final String? assignedTo;
  final String financeAssetId;
  final String lastAudit;
}

@immutable
class InventoryCategory {
  const InventoryCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.assetCount,
    required this.totalValue,
    required this.depreciationRate,
    required this.responsibleDept,
    required this.description,
  });

  final String id;
  final String name;
  final InventoryCategoryType type;
  final int assetCount;
  final String totalValue;
  final String depreciationRate;
  final String responsibleDept;
  final String description;
}

@immutable
class InventoryAllocation {
  const InventoryAllocation({
    required this.id,
    required this.assetTag,
    required this.assetName,
    required this.department,
    required this.assignedTo,
    required this.assignedDate,
    required this.returnDue,
    required this.status,
    required this.hrEmployeeId,
    required this.hostelBlock,
    required this.librarySection,
    required this.integrationNote,
  });

  final String id;
  final String assetTag;
  final String assetName;
  final String department;
  final String assignedTo;
  final String assignedDate;
  final String returnDue;
  final InventoryAllocationStatus status;
  final String? hrEmployeeId;
  final String? hostelBlock;
  final String? librarySection;
  final String integrationNote;
}

@immutable
class InventoryMaintenanceRecord {
  const InventoryMaintenanceRecord({
    required this.id,
    required this.assetTag,
    required this.assetName,
    required this.maintenanceType,
    required this.scheduledDate,
    required this.technician,
    required this.hrTechnicianId,
    required this.estimatedCost,
    required this.status,
    required this.financeBudgetCode,
  });

  final String id;
  final String assetTag;
  final String assetName;
  final String maintenanceType;
  final String scheduledDate;
  final String technician;
  final String hrTechnicianId;
  final String estimatedCost;
  final InventoryMaintenanceStatus status;
  final String financeBudgetCode;
}

@immutable
class InventoryProcurementOrder {
  const InventoryProcurementOrder({
    required this.id,
    required this.poNumber,
    required this.vendorName,
    required this.items,
    required this.totalAmount,
    required this.orderDate,
    required this.expectedDelivery,
    required this.status,
    required this.financePoId,
    required this.requestedBy,
  });

  final String id;
  final String poNumber;
  final String vendorName;
  final String items;
  final String totalAmount;
  final String orderDate;
  final String expectedDelivery;
  final InventoryProcurementStatus status;
  final String financePoId;
  final String requestedBy;
}

@immutable
class InventoryVendor {
  const InventoryVendor({
    required this.id,
    required this.name,
    required this.category,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.gstNumber,
    required this.activeOrders,
    required this.totalSpend,
    required this.status,
    required this.financeVendorId,
  });

  final String id;
  final String name;
  final String category;
  final String contactPerson;
  final String phone;
  final String email;
  final String gstNumber;
  final int activeOrders;
  final String totalSpend;
  final InventoryVendorStatus status;
  final String financeVendorId;
}

@immutable
class InventoryActivityItem {
  const InventoryActivityItem({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.actor,
    required this.moduleLink,
  });

  final String id;
  final String description;
  final String timestamp;
  final String actor;
  final String moduleLink;
}

@immutable
class InventoryStockAlert {
  const InventoryStockAlert({
    required this.id,
    required this.itemName,
    required this.category,
    required this.currentStock,
    required this.reorderLevel,
    required this.department,
  });

  final String id;
  final String itemName;
  final String category;
  final int currentStock;
  final int reorderLevel;
  final String department;
}

@immutable
class InventoryDashboardData {
  const InventoryDashboardData({
    required this.kpis,
    required this.recentActivity,
    required this.stockAlerts,
    required this.aiInsight,
    required this.integrationLinks,
  });

  final List<InventoryKpi> kpis;
  final List<InventoryActivityItem> recentActivity;
  final List<InventoryStockAlert> stockAlerts;
  final String aiInsight;
  final List<String> integrationLinks;
}

@immutable
class InventoryReportCatalogItem {
  const InventoryReportCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.lastGenerated,
  });

  final String id;
  final String title;
  final String description;
  final String lastGenerated;
}

@immutable
class InventoryReportsData {
  const InventoryReportsData({
    required this.catalog,
    required this.assetValueTrend,
    required this.allocationByDept,
    required this.procurementTrend,
  });

  final List<InventoryReportCatalogItem> catalog;
  final List<InventoryTrendPoint> assetValueTrend;
  final List<InventorySegment> allocationByDept;
  final List<InventoryTrendPoint> procurementTrend;
}
