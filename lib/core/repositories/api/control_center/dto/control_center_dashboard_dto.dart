/// JSON DTO for ControlCenter dashboard API response (scaffolding).
class ControlCenterDashboardDto {
  const ControlCenterDashboardDto({required this.raw});

  factory ControlCenterDashboardDto.fromJson(Map<String, dynamic> json) {
    return ControlCenterDashboardDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
