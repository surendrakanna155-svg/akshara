import 'package:flutter/foundation.dart';

@immutable
class ClassMappingRule {
  const ClassMappingRule({
    required this.sourceClassLabel,
    required this.sourceSection,
    required this.targetClassLabel,
    required this.targetSection,
    this.includeStudents = true,
  });

  final String sourceClassLabel;
  final String sourceSection;
  final String targetClassLabel;
  final String targetSection;
  final bool includeStudents;
}

enum AcademicTransitionJobStatus { pending, previewed, executed, failed }

@immutable
class TransitionPreviewRow {
  const TransitionPreviewRow({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.fromClassLabel,
    required this.fromSection,
    required this.toClassLabel,
    required this.toSection,
    required this.reason,
  });

  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String fromClassLabel;
  final String fromSection;
  final String toClassLabel;
  final String toSection;
  final String reason;
}

@immutable
class AcademicTransitionJob {
  const AcademicTransitionJob({
    required this.id,
    required this.sourceYearId,
    required this.targetYearId,
    required this.status,
    required this.createdAt,
    required this.mappingRules,
    required this.previewRows,
  });

  final String id;
  final String sourceYearId;
  final String targetYearId;
  final AcademicTransitionJobStatus status;
  final DateTime createdAt;
  final List<ClassMappingRule> mappingRules;
  final List<TransitionPreviewRow> previewRows;
}

@immutable
class ReshufflePlan {
  const ReshufflePlan({
    required this.id,
    required this.classLabel,
    required this.academicYear,
    required this.strategy,
    required this.previewRows,
  });

  final String id;
  final String classLabel;
  final String academicYear;
  final String strategy;
  final List<TransitionPreviewRow> previewRows;
}

@immutable
class SectionBalancePlan {
  const SectionBalancePlan({
    required this.id,
    required this.classLabel,
    required this.academicYear,
    required this.targetSectionSize,
    required this.previewRows,
  });

  final String id;
  final String classLabel;
  final String academicYear;
  final int targetSectionSize;
  final List<TransitionPreviewRow> previewRows;
}

@immutable
class QuarterlyReshufflePlan {
  const QuarterlyReshufflePlan({
    required this.id,
    required this.classLabel,
    required this.academicYear,
    required this.quarter,
    required this.previewRows,
  });

  final String id;
  final String classLabel;
  final String academicYear;
  final int quarter;
  final List<TransitionPreviewRow> previewRows;
}

@immutable
class PerformanceBalancePlan {
  const PerformanceBalancePlan({
    required this.id,
    required this.classLabel,
    required this.academicYear,
    required this.previewRows,
  });

  final String id;
  final String classLabel;
  final String academicYear;
  final List<TransitionPreviewRow> previewRows;
}

@immutable
class AcademicTransitionExecutionReport {
  const AcademicTransitionExecutionReport({
    required this.jobId,
    required this.executedCount,
    required this.skippedCount,
    required this.executedAt,
  });

  final String jobId;
  final int executedCount;
  final int skippedCount;
  final DateTime executedAt;
}

@immutable
class AcademicOperationExecutionReport {
  const AcademicOperationExecutionReport({
    required this.planId,
    required this.executedCount,
    required this.skippedCount,
    required this.executedAt,
  });

  final String planId;
  final int executedCount;
  final int skippedCount;
  final DateTime executedAt;
}
