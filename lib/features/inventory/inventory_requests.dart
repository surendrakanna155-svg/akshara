import 'inventory_models.dart';

class CreateInventoryProcurementOrderRequest {
  const CreateInventoryProcurementOrderRequest({
    required this.vendorName,
    required this.items,
    required this.totalAmount,
    required this.requestedBy,
    this.vendorId,
    this.expectedDelivery = 'TBD',
    this.financePoId,
    this.poNumber,
  });

  /// Finance vendor-catalog id (`inventory_vendors.id`) the PO is raised
  /// against. Required for the finance PO write; null only on the rebuilt
  /// request the notifier passes to the inventory repo (which already has the
  /// resolved [financePoId]).
  final String? vendorId;
  final String vendorName;
  final String items;
  final String totalAmount;
  final String requestedBy;
  final String expectedDelivery;
  final String? financePoId;
  final String? poNumber;
}

class CreateInventoryProcurementOrderResult {
  const CreateInventoryProcurementOrderResult({
    required this.order,
  });

  final InventoryProcurementOrder order;
}
