import '../../../../../features/sis/academic_operations/academic_operations_models.dart';
import '../dto/academic_operations_response_dto.dart';

class AcademicOperationsMapper {
  const AcademicOperationsMapper();

  List<ClassMappingRule> toMappingRules(
    List<ClassMappingRuleResponseDto> rows,
  ) {
    return rows.map(toMappingRule).toList(growable: false);
  }

  ClassMappingRule toMappingRule(ClassMappingRuleResponseDto row) {
    return ClassMappingRule(
      sourceClassLabel: row.sourceClassLabel,
      sourceSection: row.sourceSection,
      targetClassLabel: row.targetClassLabel,
      targetSection: row.targetSection,
      includeStudents: row.includeStudents,
    );
  }

  AcademicTransitionJob toTransitionJob(AcademicTransitionJobResponseDto dto) {
    return AcademicTransitionJob(
      id: dto.id,
      sourceYearId: dto.sourceYearId,
      targetYearId: dto.targetYearId,
      status: _status(dto.status),
      createdAt: _parseDate(dto.createdAtIso),
      mappingRules: toMappingRules(dto.mappingRules),
      previewRows: dto.previewRows.map(toPreviewRow).toList(growable: false),
    );
  }

  ReshufflePlan toReshufflePlan(AcademicOperationPlanResponseDto dto) {
    return ReshufflePlan(
      id: dto.id,
      classLabel: dto.classLabel,
      academicYear: dto.academicYear,
      strategy: dto.strategy,
      previewRows: dto.previewRows.map(toPreviewRow).toList(growable: false),
    );
  }

  SectionBalancePlan toSectionBalancePlan(AcademicOperationPlanResponseDto dto) {
    return SectionBalancePlan(
      id: dto.id,
      classLabel: dto.classLabel,
      academicYear: dto.academicYear,
      targetSectionSize: dto.targetSectionSize ?? 30,
      previewRows: dto.previewRows.map(toPreviewRow).toList(growable: false),
    );
  }

  QuarterlyReshufflePlan toQuarterlyPlan(AcademicOperationPlanResponseDto dto) {
    return QuarterlyReshufflePlan(
      id: dto.id,
      classLabel: dto.classLabel,
      academicYear: dto.academicYear,
      quarter: dto.quarter ?? 1,
      previewRows: dto.previewRows.map(toPreviewRow).toList(growable: false),
    );
  }

  PerformanceBalancePlan toPerformancePlan(AcademicOperationPlanResponseDto dto) {
    return PerformanceBalancePlan(
      id: dto.id,
      classLabel: dto.classLabel,
      academicYear: dto.academicYear,
      previewRows: dto.previewRows.map(toPreviewRow).toList(growable: false),
    );
  }

  AcademicTransitionExecutionReport toTransitionExecutionReport(
    ExecutionReportResponseDto dto,
  ) {
    return AcademicTransitionExecutionReport(
      jobId: dto.id,
      executedCount: dto.executedCount,
      skippedCount: dto.skippedCount,
      executedAt: _parseDate(dto.executedAtIso),
    );
  }

  AcademicOperationExecutionReport toExecutionReport(
    ExecutionReportResponseDto dto,
  ) {
    return AcademicOperationExecutionReport(
      planId: dto.id,
      executedCount: dto.executedCount,
      skippedCount: dto.skippedCount,
      executedAt: _parseDate(dto.executedAtIso),
    );
  }

  TransitionPreviewRow toPreviewRow(TransitionPreviewRowResponseDto dto) {
    return TransitionPreviewRow(
      studentId: dto.studentId,
      studentName: dto.studentName,
      admissionNumber: dto.admissionNumber,
      fromClassLabel: dto.fromClassLabel,
      fromSection: dto.fromSection,
      toClassLabel: dto.toClassLabel,
      toSection: dto.toSection,
      reason: dto.reason,
    );
  }

  AcademicTransitionJobStatus _status(String value) {
    // PRA-P0-14: backend uses `completed` for a successfully executed job.
    return switch (value) {
      'previewed' => AcademicTransitionJobStatus.previewed,
      'completed' || 'executed' => AcademicTransitionJobStatus.executed,
      'failed' => AcademicTransitionJobStatus.failed,
      _ => AcademicTransitionJobStatus.pending,
    };
  }

  DateTime _parseDate(String value) {
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }
}
