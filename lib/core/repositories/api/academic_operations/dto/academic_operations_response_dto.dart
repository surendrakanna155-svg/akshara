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
      // PRA-P0-14: backend stores the mapping under `classMapping` and the
      // affected students under `previewReport.rows` (see academic_transition_
      // handlers.ts / repository.ts). Fall back to the legacy flat keys.
      mappingRules: _list(json['classMapping'] ?? json['mappingRules'])
          .map(ClassMappingRuleResponseDto.fromJson)
          .toList(growable: false),
      previewRows: _transitionPreviewRows(json)
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
    // PRA-P0-14: backend emits `sourceClassName / targetClassName / keepSection /
    // action`; suggestions are class-level (no section strings). Map onto the
    // existing domain-shaped fields, deriving `includeStudents` from `action`
    // (skip => excluded). Legacy flat keys kept as a fallback.
    final action = json['action'] as String?;
    return ClassMappingRuleResponseDto(
      sourceClassLabel:
          (json['sourceClassName'] ?? json['sourceClassLabel']) as String? ?? '',
      sourceSection: json['sourceSection'] as String? ?? '',
      targetClassLabel:
          (json['targetClassName'] ?? json['targetClassLabel']) as String? ?? '',
      targetSection: json['targetSection'] as String? ?? '',
      includeStudents: action != null
          ? action != 'skip'
          : (json['includeStudents'] as bool? ?? true),
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
    // PRA-P0-14: transition preview rows use `sourceClassName / targetClassName
    // / sourceSectionName / targetSectionName / status / errors`. Fall back to
    // the flat `from*/to*/reason` keys still used by the (deferred, mock-only)
    // reshuffle/section-balance operation plans that share this DTO.
    final errors = (json['errors'] as List?) ?? const [];
    return TransitionPreviewRowResponseDto(
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      admissionNumber: json['admissionNumber'] as String? ?? '',
      fromClassLabel:
          (json['sourceClassName'] ?? json['fromClassLabel']) as String? ?? '',
      fromSection:
          (json['sourceSectionName'] ?? json['fromSection']) as String? ?? '',
      toClassLabel:
          (json['targetClassName'] ?? json['toClassLabel']) as String? ?? '',
      toSection:
          (json['targetSectionName'] ?? json['toSection']) as String? ?? '',
      reason: (json['reason'] as String?) ??
          (errors.isNotEmpty
              ? errors.join('; ')
              : (json['status'] as String? ?? '')),
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
    // PRA-P0-14: the executed transition job reports moved students as
    // `promotedCount` (legacy flat mock used `executedCount`).
    return ExecutionReportResponseDto(
      id: json['id'] as String? ?? '',
      executedCount:
          ((json['promotedCount'] ?? json['executedCount']) as num?)?.toInt() ??
              0,
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

/// PRA-P0-14: affected students live under `previewReport.rows` for both the
/// preview and get-job responses. Fall back to a flat `previewRows` list.
List<Map<String, dynamic>> _transitionPreviewRows(Map<String, dynamic> json) {
  final report = json['previewReport'];
  if (report is Map && report['rows'] is List) {
    return _list(report['rows']);
  }
  return _list(json['previewRows']);
}
