import 'package:flutter/material.dart';

import '../../../../../features/inventory/inventory_models.dart';

/// Parses Inventory API enum strings and presentation helpers.
abstract final class InventoryEnumCodec {
  static InventoryAssetStatus parseAssetStatus(String? value) {
    return InventoryAssetStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => InventoryAssetStatus.available,
    );
  }

  static String assetStatusToApi(InventoryAssetStatus status) => status.name;

  static InventoryCategoryType parseCategoryType(String? value) {
    return InventoryCategoryType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => InventoryCategoryType.equipment,
    );
  }

  static String categoryTypeToApi(InventoryCategoryType type) => type.name;

  static InventoryAllocationStatus parseAllocationStatus(String? value) {
    return InventoryAllocationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => InventoryAllocationStatus.active,
    );
  }

  static String allocationStatusToApi(InventoryAllocationStatus status) =>
      status.name;

  static InventoryMaintenanceStatus parseMaintenanceStatus(String? value) {
    return InventoryMaintenanceStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => InventoryMaintenanceStatus.scheduled,
    );
  }

  static String maintenanceStatusToApi(InventoryMaintenanceStatus status) =>
      status.name;

  static InventoryProcurementStatus parseProcurementStatus(String? value) {
    return InventoryProcurementStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => InventoryProcurementStatus.draft,
    );
  }

  static String procurementStatusToApi(InventoryProcurementStatus status) =>
      status.name;

  static InventoryVendorStatus parseVendorStatus(String? value) {
    return InventoryVendorStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => InventoryVendorStatus.active,
    );
  }

  static String vendorStatusToApi(InventoryVendorStatus status) => status.name;

  static IconData iconForKpi(String? iconName, String? accentName, String? id) {
    if (iconName != null && iconName.isNotEmpty) {
      return switch (iconName) {
        'inventory_2_outlined' => Icons.inventory_2_outlined,
        'assignment_outlined' => Icons.assignment_outlined,
        'build_outlined' => Icons.build_outlined,
        'warning_amber_outlined' => Icons.warning_amber_outlined,
        'shopping_cart_outlined' => Icons.shopping_cart_outlined,
        'account_balance_outlined' => Icons.account_balance_outlined,
        _ => Icons.insights_outlined,
      };
    }
    return switch (id) {
      'total_assets' => Icons.inventory_2_outlined,
      'allocated' => Icons.assignment_outlined,
      'maintenance' => Icons.build_outlined,
      'low_stock' => Icons.warning_amber_outlined,
      'procurement' => Icons.shopping_cart_outlined,
      'asset_value' => Icons.account_balance_outlined,
      _ => switch (accentName) {
          'primary' => Icons.inventory_2_outlined,
          'success' => Icons.assignment_outlined,
          'warning' => Icons.build_outlined,
          'error' => Icons.warning_amber_outlined,
          _ => Icons.insights_outlined,
        },
    };
  }
}
