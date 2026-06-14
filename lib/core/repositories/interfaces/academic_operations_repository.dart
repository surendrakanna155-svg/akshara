import '../../../features/sis/academic_operations/academic_operations_models.dart';
import '../repository_query.dart';

abstract class AcademicOperationsRepository {
  Future<List<ClassMappingRule>> suggestClassMappings({
    required RepositoryQuery query,
    required String sourceYearId,
    required String targetYearId,
  });

  Future<AcademicTransitionJob> previewYearTransition({
    required RepositoryQuery query,
    required String sourceYearId,
    required String targetYearId,
    required List<ClassMappingRule> mappings,
  });

  Future<AcademicTransitionExecutionReport> executeYearTransition({
    required RepositoryQuery query,
    required String jobId,
  });

  Future<AcademicTransitionJob> getTransitionJob({
    required RepositoryQuery query,
    required String jobId,
  });

  Future<ReshufflePlan> previewStudentReshuffle({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    required String strategy,
  });

  Future<AcademicOperationExecutionReport> executeStudentReshuffle({
    required RepositoryQuery query,
    required String planId,
  });

  Future<SectionBalancePlan> previewSectionBalance({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    int? targetSize,
  });

  Future<AcademicOperationExecutionReport> executeSectionBalance({
    required RepositoryQuery query,
    required String planId,
  });

  Future<QuarterlyReshufflePlan> previewQuarterlyReshuffle({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    required int quarter,
  });

  Future<AcademicOperationExecutionReport> executeQuarterlyReshuffle({
    required RepositoryQuery query,
    required String planId,
  });

  Future<PerformanceBalancePlan> previewPerformanceBalance({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
  });

  Future<AcademicOperationExecutionReport> executePerformanceBalance({
    required RepositoryQuery query,
    required String planId,
  });
}
