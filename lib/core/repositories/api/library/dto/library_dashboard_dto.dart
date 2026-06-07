/// JSON DTO for Library dashboard API response (scaffolding).
class LibraryDashboardDto {
  const LibraryDashboardDto({required this.raw});

  factory LibraryDashboardDto.fromJson(Map<String, dynamic> json) {
    return LibraryDashboardDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
