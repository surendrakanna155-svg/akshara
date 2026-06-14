class AcademicTransitionJobResponseDto {
  const AcademicTransitionJobResponseDto({
    required this.id,
    required this.sourceYearId,
    required this.targetYearId,
    required this.status,
    required this.createdAtIso,
    required this.mappingRules,
    required this.previewRows,
  });

  factory AcademicTransitionJobResponseDto.fromJson(Map<String, dynamic> json) {
    return AcademicTransitionJobResponseDto(
      id: json['id'] as String? ?? '',
      sourceYearId: json['sourceYearId'] as String? ?? '',
      targetYearId: json['targetYearId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAtIso: json['createdAt'] as String? ?? '',
      mappingRules: _list(json['mappingRules'])
          .map(ClassMappingRuleResponseDto.fromJson)
          .toList(growable: false),
      previewRows: _list(json['previewRows'])
          .map(TransitionPreviewRowResponseDto.fromJson)
          .toList(growable: false),
    );
  }

  final String id;
  final String sourceYearId;
  final String targetYearId;
  final String status;
  final String createdAtIso;
  final List<ClassMappingRuleResponseDto> mappingRules;
  final List<TransitionPreviewRowResponseDto> previewRows;
}

class ClassMappingRuleResponseDto {
  const ClassMappingRuleResponseDto({
    required this.sourceClassLabel,
    required this.sourceSection,
    required this.targetClassLabel,
    required this.targetSection,
    required this.includeStudents,
  });

  factory ClassMappingRuleResponseDto.fromJson(Map<String, dynamic> json) {
    return ClassMappingRuleResponseDto(
      sourceClassLabel: json['sourceClassLabel'] as String? ?? '',
      sourceSection: json['sourceSection'] as String? ?? '',
      targetClassLabel: json['targetClassLabel'] as String? ?? '',
      targetSection: json['targetSection'] as String? ?? '',
      includeStudents: json['includeStudents'] as bool? ?? true,
    );
  }

  final String sourceClassLabel;
  final String sourceSection;
  final String targetClassLabel;
  final String targetSection;
  final bool includeStudents;
}

class TransitionPreviewRowResponseDto {
  const TransitionPreviewRowResponseDto({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.fromClassLabel,
    required this.fromSection,
    required this.toClassLabel,
    required this.toSection,
    required this.reason,
  });

  factory TransitionPreviewRowResponseDto.fromJson(Map<String, dynamic> json) {
    return TransitionPreviewRowResponseDto(
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      admissionNumber: json['admissionNumber'] as String? ?? '',
      fromClassLabel: json['fromClassLabel'] as String? ?? '',
      fromSection: json['fromSection'] as String? ?? '',
      toClassLabel: json['toClassLabel'] as String? ?? '',
      toSection: json['toSection'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }

  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String fromClassLabel;
  final String fromSection;
  final String toClassLabel;
  final String toSection;
  final String reason;
}

class AcademicOperationPlanResponseDto {
  const AcademicOperationPlanResponseDto({
    required this.id,
    required this.classLabel,
    required this.academicYear,
    required this.strategy,
    required this.quarter,
    required this.targetSectionSize,
    required this.previewRows,
  });

  factory AcademicOperationPlanResponseDto.fromJson(Map<String, dynamic> json) {
    return AcademicOperationPlanResponseDto(
      id: json['id'] as String? ?? '',
      classLabel: json['classLabel'] as String? ?? '',
      academicYear: json['academicYear'] as String? ?? '',
      strategy: json['strategy'] as String? ?? '',
      quarter: (json['quarter'] as num?)?.toInt(),
      targetSectionSize: (json['targetSectionSize'] as num?)?.toInt(),
      previewRows: _list(json['previewRows'])
          .map(TransitionPreviewRowResponseDto.fromJson)
          .toList(growable: false),
    );
  }

  final String id;
  final String classLabel;
  final String academicYear;
  final String strategy;
  final int? quarter;
  final int? targetSectionSize;
  final List<TransitionPreviewRowResponseDto> previewRows;
}

class ExecutionReportResponseDto {
  const ExecutionReportResponseDto({
    required this.id,
    required this.executedCount,
    required this.skippedCount,
    required this.executedAtIso,
  });

  factory ExecutionReportResponseDto.fromJson(Map<String, dynamic> json) {
    return ExecutionReportResponseDto(
      id: json['id'] as String? ?? '',
      executedCount: (json['executedCount'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skippedCount'] as num?)?.toInt() ?? 0,
      executedAtIso: json['executedAt'] as String? ?? '',
    );
  }

  final String id;
  final int executedCount;
  final int skippedCount;
  final String executedAtIso;
}

List<Map<String, dynamic>> _list(Object? value) {
  final list = value as List<dynamic>? ?? const [];
  return list
      .whereType<Map>()
      .map((row) => row.cast<String, dynamic>())
      .toList(growable: false);
}
