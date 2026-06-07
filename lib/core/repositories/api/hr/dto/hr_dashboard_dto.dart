/// JSON DTO for Hr dashboard API response (scaffolding).
class HrDashboardDto {
  const HrDashboardDto({required this.raw});

  factory HrDashboardDto.fromJson(Map<String, dynamic> json) {
    return HrDashboardDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
