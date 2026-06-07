/// JSON DTO for Management dashboard API response (scaffolding).
class ManagementDashboardDto {
  const ManagementDashboardDto({required this.raw});

  factory ManagementDashboardDto.fromJson(Map<String, dynamic> json) {
    return ManagementDashboardDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
