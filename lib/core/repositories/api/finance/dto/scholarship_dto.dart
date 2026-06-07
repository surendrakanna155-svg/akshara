class ScholarshipDto {
  const ScholarshipDto({required this.raw});

  factory ScholarshipDto.fromJson(Map<String, dynamic> json) {
    return ScholarshipDto(raw: json);
  }

  final Map<String, dynamic> raw;
}
