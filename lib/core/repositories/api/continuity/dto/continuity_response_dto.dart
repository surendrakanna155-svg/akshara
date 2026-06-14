class ContinuityMigrationPlanDto {
  const ContinuityMigrationPlanDto({
    required this.raw,
  });

  factory ContinuityMigrationPlanDto.fromJson(Map<String, dynamic> json) {
    return ContinuityMigrationPlanDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class ContinuityMigrationResultDto {
  const ContinuityMigrationResultDto({
    required this.raw,
  });

  factory ContinuityMigrationResultDto.fromJson(Map<String, dynamic> json) {
    return ContinuityMigrationResultDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class ContinuityAuditTrailDto {
  const ContinuityAuditTrailDto({
    required this.items,
  });

  factory ContinuityAuditTrailDto.fromJson(Map<String, dynamic> json) {
    final rows = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList(growable: false);
    return ContinuityAuditTrailDto(items: rows);
  }

  final List<Map<String, dynamic>> items;
}
