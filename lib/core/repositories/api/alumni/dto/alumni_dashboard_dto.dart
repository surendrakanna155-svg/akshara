/// JSON DTO for Alumni dashboard API response (scaffolding).
class AlumniDashboardDto {
  const AlumniDashboardDto({required this.raw});

  factory AlumniDashboardDto.fromJson(Map<String, dynamic> json) {
    return AlumniDashboardDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
