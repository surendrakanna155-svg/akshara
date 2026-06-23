import '../../../../../features/inventory/inventory_models.dart';
import '../dto/inventory_enum_codec.dart';
import '../dto/inventory_responses_dto.dart';

/// Maps Inventory API DTOs to domain models.
class InventoryMapper {
  const InventoryMapper();

  InventoryDashboardData toDashboard(InventoryDashboardDto dto) {
    final raw = dto.raw;
    return InventoryDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      recentActivity: _mapActivityItems(
        raw['recentActivity'] as List<dynamic>? ?? const [],
      ),
      stockAlerts: _mapStockAlerts(
        raw['stockAlerts'] as List<dynamic>? ?? const [],
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
      integrationLinks: _stringList(raw['integrationLinks']),
    );
  }

  List<InventoryAsset> toAssets(InventoryAssetsResponseDto dto) {
    return [for (final item in dto.items) toAsset(item)];
  }

  InventoryAsset toAsset(InventoryAssetDto dto) {
    final raw = dto.raw;
    return InventoryAsset(
      id: raw['id'] as String? ?? '',
      assetTag: raw['assetTag'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      category: raw['category'] as String? ?? '',
      location: raw['location'] as String? ?? '',
      purchaseDate: raw['purchaseDate'] as String? ?? '',
      value: raw['value'] as String? ?? '',
      status: InventoryEnumCodec.parseAssetStatus(raw['status'] as String?),
      assignedTo: raw['assignedTo'] as String?,
      financeAssetId: raw['financeAssetId'] as String? ?? '',
      lastAudit: raw['lastAudit'] as String? ?? '',
    );
  }

  List<InventoryCategory> toCategories(InventoryCategoriesResponseDto dto) {
    return [for (final item in dto.items) toCategory(item)];
  }

  InventoryCategory toCategory(InventoryCategoryDto dto) {
    final raw = dto.raw;
    return InventoryCategory(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      type: InventoryEnumCodec.parseCategoryType(raw['type'] as String?),
      assetCount: raw['assetCount'] as int? ?? 0,
      totalValue: raw['totalValue'] as String? ?? '',
      depreciationRate: raw['depreciationRate'] as String? ?? '',
      responsibleDept: raw['responsibleDept'] as String? ?? '',
      description: raw['description'] as String? ?? '',
    );
  }

  List<InventoryAllocation> toAllocations(InventoryAllocationsResponseDto dto) {
    return [for (final item in dto.items) toAllocation(item)];
  }

  InventoryAllocation toAllocation(InventoryAllocationDto dto) {
    final raw = dto.raw;
    return InventoryAllocation(
      id: raw['id'] as String? ?? '',
      assetTag: raw['assetTag'] as String? ?? '',
      assetName: raw['assetName'] as String? ?? '',
      department: raw['department'] as String? ?? '',
      assignedTo: raw['assignedTo'] as String? ?? '',
      assignedDate: raw['assignedDate'] as String? ?? '',
      returnDue: raw['returnDue'] as String? ?? '',
      status: InventoryEnumCodec.parseAllocationStatus(
        raw['status'] as String?,
      ),
      hrEmployeeId: raw['hrEmployeeId'] as String?,
      hostelBlock: raw['hostelBlock'] as String?,
      librarySection: raw['librarySection'] as String?,
      integrationNote: raw['integrationNote'] as String? ?? '',
    );
  }

  List<InventoryMaintenanceRecord> toMaintenanceRecords(
    InventoryMaintenanceResponseDto dto,
  ) {
    return [for (final item in dto.items) toMaintenanceRecord(item)];
  }

  InventoryMaintenanceRecord toMaintenanceRecord(
    InventoryMaintenanceRecordDto dto,
  ) {
    final raw = dto.raw;
    return InventoryMaintenanceRecord(
      id: raw['id'] as String? ?? '',
      assetTag: raw['assetTag'] as String? ?? '',
      assetName: raw['assetName'] as String? ?? '',
      maintenanceType: raw['maintenanceType'] as String? ?? '',
      scheduledDate: raw['scheduledDate'] as String? ?? '',
      technician: raw['technician'] as String? ?? '',
      hrTechnicianId: raw['hrTechnicianId'] as String? ?? '',
      estimatedCost: raw['estimatedCost'] as String? ?? '',
      status: InventoryEnumCodec.parseMaintenanceStatus(
        raw['status'] as String?,
      ),
      financeBudgetCode: raw['financeBudgetCode'] as String? ?? '',
    );
  }

  List<InventoryProcurementOrder> toProcurementOrders(
    InventoryProcurementResponseDto dto,
  ) {
    return [for (final item in dto.items) toProcurementOrder(item)];
  }

  InventoryProcurementOrder toProcurementOrder(
      InventoryProcurementOrderDto dto) {
    final raw = dto.raw;
    return InventoryProcurementOrder(
      id: raw['id'] as String? ?? '',
      poNumber: raw['poNumber'] as String? ?? '',
      vendorName: raw['vendorName'] as String? ?? '',
      items: raw['items'] as String? ?? '',
      totalAmount: raw['totalAmount'] as String? ?? '',
      orderDate: raw['orderDate'] as String? ?? '',
      expectedDelivery: raw['expectedDelivery'] as String? ?? '',
      status: InventoryEnumCodec.parseProcurementStatus(
        raw['status'] as String?,
      ),
      financePoId: raw['financePoId'] as String? ?? '',
      requestedBy: raw['requestedBy'] as String? ?? '',
      approvalHistory: _mapProcurementApprovalHistory(
        raw['approvalHistory'] as List<dynamic>? ?? const [],
      ),
    );
  }

  /// Adapts the procurement-order row returned by the inventory finance write
  /// endpoints (`poToApi` shape: `id`, `poNumber`, `vendorId`, `status`,
  /// `totalAmount` as a number, `currency`, `createdAt`) into the app's
  /// [InventoryProcurementOrder].
  ///
  /// The server PO row omits several presentation-only fields the app model
  /// carries (`vendorName`, `items`, `expectedDelivery`, `financePoId`,
  /// `requestedBy`). When known (e.g. from the originating create request) they
  /// are supplied via the optional [context] map and merged here; otherwise
  /// they fall back to a safe default.
  InventoryProcurementOrder toProcurementOrderFromServerRow(
    Map<String, dynamic> row, {
    Map<String, String?> context = const {},
  }) {
    final totalAmountRaw = row['totalAmount'];
    final totalAmount = totalAmountRaw is num
        ? totalAmountRaw.toString()
        : (totalAmountRaw as String? ?? context['totalAmount'] ?? '');
    final createdAt = row['createdAt'] as String? ?? '';
    return InventoryProcurementOrder(
      id: row['id'] as String? ?? '',
      poNumber: row['poNumber'] as String? ?? context['poNumber'] ?? '',
      vendorName: context['vendorName'] ?? row['vendorId'] as String? ?? '',
      items: context['items'] ?? '',
      totalAmount: totalAmount,
      orderDate: context['orderDate'] ?? createdAt,
      expectedDelivery: context['expectedDelivery'] ?? '',
      status: InventoryEnumCodec.parsePurchaseOrderStatus(
        row['status'] as String?,
      ),
      financePoId: context['financePoId'] ?? '',
      requestedBy: context['requestedBy'] ?? '',
    );
  }

  List<InventoryVendor> toVendors(InventoryVendorsResponseDto dto) {
    return [for (final item in dto.items) toVendor(item)];
  }

  InventoryVendor toVendor(InventoryVendorDto dto) {
    final raw = dto.raw;
    return InventoryVendor(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      category: raw['category'] as String? ?? '',
      contactPerson: raw['contactPerson'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      email: raw['email'] as String? ?? '',
      gstNumber: raw['gstNumber'] as String? ?? '',
      activeOrders: raw['activeOrders'] as int? ?? 0,
      totalSpend: raw['totalSpend'] as String? ?? '',
      status: InventoryEnumCodec.parseVendorStatus(raw['status'] as String?),
      financeVendorId: raw['financeVendorId'] as String? ?? '',
    );
  }

  InventoryReportsData toReports(InventoryReportsResponseDto dto) {
    final raw = dto.raw;
    return InventoryReportsData(
      catalog: _mapReportCatalog(raw['catalog'] as List<dynamic>? ?? const []),
      assetValueTrend: _mapTrendPoints(
        raw['assetValueTrend'] as List<dynamic>? ?? const [],
      ),
      allocationByDept: _mapSegments(
        raw['allocationByDept'] as List<dynamic>? ?? const [],
      ),
      procurementTrend: _mapTrendPoints(
        raw['procurementTrend'] as List<dynamic>? ?? const [],
      ),
    );
  }

  List<InventoryKpi> _mapKpis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          InventoryKpi(
            id: item['id'] as String? ?? '',
            value: item['value'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: InventoryEnumCodec.iconForKpi(
              item['icon'] as String?,
              item['accentName'] as String?,
              item['id'] as String?,
            ),
            accentName: item['accentName'] as String? ?? 'neutral',
            detail: item['detail'] as String?,
          ),
    ];
  }

  List<InventoryTrendPoint> _mapTrendPoints(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          InventoryTrendPoint(
            label: item['label'] as String? ?? '',
            amountLakhs: (item['amountLakhs'] as num?)?.toDouble() ?? 0,
            targetLakhs: (item['targetLakhs'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<InventorySegment> _mapSegments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          InventorySegment(
            label: item['label'] as String? ?? '',
            value: (item['value'] as num?)?.toDouble() ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<InventoryActivityItem> _mapActivityItems(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          InventoryActivityItem(
            id: item['id'] as String? ?? '',
            description: item['description'] as String? ?? '',
            timestamp: item['timestamp'] as String? ?? '',
            actor: item['actor'] as String? ?? '',
            moduleLink: item['moduleLink'] as String? ?? '',
          ),
    ];
  }

  List<InventoryStockAlert> _mapStockAlerts(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          InventoryStockAlert(
            id: item['id'] as String? ?? '',
            itemName: item['itemName'] as String? ?? '',
            category: item['category'] as String? ?? '',
            currentStock: item['currentStock'] as int? ?? 0,
            reorderLevel: item['reorderLevel'] as int? ?? 0,
            department: item['department'] as String? ?? '',
          ),
    ];
  }

  List<InventoryReportCatalogItem> _mapReportCatalog(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          InventoryReportCatalogItem(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            description: item['description'] as String? ?? '',
            lastGenerated: item['lastGenerated'] as String? ?? '',
          ),
    ];
  }

  List<InventoryProcurementApprovalEntry> _mapProcurementApprovalHistory(
    List<dynamic> items,
  ) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          InventoryProcurementApprovalEntry(
            action: item['action'] as String? ?? '',
            actor: item['actor'] as String? ?? '',
            recordedAt: item['recordedAt'] as String? ?? '',
            note: item['note'] as String?,
          ),
    ];
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item != null) '$item',
    ];
  }
}
