/// JSON DTO for Transport dashboard API response (scaffolding).
class TransportDashboardDto {
  const TransportDashboardDto({required this.raw});

  factory TransportDashboardDto.fromJson(Map<String, dynamic> json) {
    return TransportDashboardDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
