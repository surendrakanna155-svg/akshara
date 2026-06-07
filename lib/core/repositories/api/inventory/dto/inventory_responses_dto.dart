import '../../admissions/dto/api_envelope_dto.dart';

class InventoryDashboardDto {
  const InventoryDashboardDto({required this.raw});

  factory InventoryDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return InventoryDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class InventoryAssetDto {
  const InventoryAssetDto({required this.raw});

  factory InventoryAssetDto.fromJson(Map<String, dynamic> json) {
    return InventoryAssetDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class InventoryAssetsResponseDto {
  const InventoryAssetsResponseDto({required this.items});

  factory InventoryAssetsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return InventoryAssetsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          InventoryAssetDto.fromJson(item),
      ],
    );
  }

  final List<InventoryAssetDto> items;
}

class InventoryCategoryDto {
  const InventoryCategoryDto({required this.raw});

  factory InventoryCategoryDto.fromJson(Map<String, dynamic> json) {
    return InventoryCategoryDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class InventoryCategoriesResponseDto {
  const InventoryCategoriesResponseDto({required this.items});

  factory InventoryCategoriesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return InventoryCategoriesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          InventoryCategoryDto.fromJson(item),
      ],
    );
  }

  final List<InventoryCategoryDto> items;
}

class InventoryAllocationDto {
  const InventoryAllocationDto({required this.raw});

  factory InventoryAllocationDto.fromJson(Map<String, dynamic> json) {
    return InventoryAllocationDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class InventoryAllocationsResponseDto {
  const InventoryAllocationsResponseDto({required this.items});

  factory InventoryAllocationsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return InventoryAllocationsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          InventoryAllocationDto.fromJson(item),
      ],
    );
  }

  final List<InventoryAllocationDto> items;
}

class InventoryMaintenanceRecordDto {
  const InventoryMaintenanceRecordDto({required this.raw});

  factory InventoryMaintenanceRecordDto.fromJson(Map<String, dynamic> json) {
    return InventoryMaintenanceRecordDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class InventoryMaintenanceResponseDto {
  const InventoryMaintenanceResponseDto({required this.items});

  factory InventoryMaintenanceResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return InventoryMaintenanceResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          InventoryMaintenanceRecordDto.fromJson(item),
      ],
    );
  }

  final List<InventoryMaintenanceRecordDto> items;
}

class InventoryProcurementOrderDto {
  const InventoryProcurementOrderDto({required this.raw});

  factory InventoryProcurementOrderDto.fromJson(Map<String, dynamic> json) {
    return InventoryProcurementOrderDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class InventoryProcurementResponseDto {
  const InventoryProcurementResponseDto({required this.items});

  factory InventoryProcurementResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return InventoryProcurementResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          InventoryProcurementOrderDto.fromJson(item),
      ],
    );
  }

  final List<InventoryProcurementOrderDto> items;
}

class InventoryVendorDto {
  const InventoryVendorDto({required this.raw});

  factory InventoryVendorDto.fromJson(Map<String, dynamic> json) {
    return InventoryVendorDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class InventoryVendorsResponseDto {
  const InventoryVendorsResponseDto({required this.items});

  factory InventoryVendorsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return InventoryVendorsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          InventoryVendorDto.fromJson(item),
      ],
    );
  }

  final List<InventoryVendorDto> items;
}

class InventoryReportsResponseDto {
  const InventoryReportsResponseDto({required this.raw});

  factory InventoryReportsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return InventoryReportsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
