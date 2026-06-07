/// JSON DTO for Inventory dashboard API response (scaffolding).
class InventoryDashboardDto {
  const InventoryDashboardDto({required this.raw});

  factory InventoryDashboardDto.fromJson(Map<String, dynamic> json) {
    return InventoryDashboardDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
