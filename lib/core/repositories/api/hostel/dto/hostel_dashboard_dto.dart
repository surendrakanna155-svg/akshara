/// JSON DTO for Hostel dashboard API response (scaffolding).
class HostelDashboardDto {
  const HostelDashboardDto({required this.raw});

  factory HostelDashboardDto.fromJson(Map<String, dynamic> json) {
    return HostelDashboardDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
