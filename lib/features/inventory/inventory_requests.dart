import 'inventory_models.dart';

class CreateInventoryProcurementOrderRequest {
  const CreateInventoryProcurementOrderRequest({
    required this.vendorName,
    required this.items,
    required this.totalAmount,
    required this.requestedBy,
    this.expectedDelivery = 'TBD',
  });

  final String vendorName;
  final String items;
  final String totalAmount;
  final String requestedBy;
  final String expectedDelivery;
}

class CreateInventoryProcurementOrderResult {
  const CreateInventoryProcurementOrderResult({
    required this.order,
  });

  final InventoryProcurementOrder order;
}
