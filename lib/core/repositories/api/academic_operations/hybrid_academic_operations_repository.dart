import '../../interfaces/academic_operations_repository.dart';
import '../../repository_query.dart';
import '../../../../features/sis/academic_operations/academic_operations_models.dart';
import 'api_academic_operations_repository.dart';

class HybridAcademicOperationsRepository implements AcademicOperationsRepository {
  HybridAcademicOperationsRepository({required ApiAcademicOperationsRepository api})
      : _api = api;

  final ApiAcademicOperationsRepository _api;

  @override
  Future<List<ClassMappingRule>> suggestClassMappings({
    required RepositoryQuery query,
    required String sourceYearId,
    required String targetYearId,
  }) =>
      _api.suggestClassMappings(
        query: query,
        sourceYearId: sourceYearId,
        targetYearId: targetYearId,
      );

  @override
  Future<AcademicTransitionJob> previewYearTransition({
    required RepositoryQuery query,
    required String sourceYearId,
    required String targetYearId,
    required List<ClassMappingRule> mappings,
  }) =>
      _api.previewYearTransition(
        query: query,
        sourceYearId: sourceYearId,
        targetYearId: targetYearId,
        mappings: mappings,
      );

  @override
  Future<AcademicTransitionExecutionReport> executeYearTransition({
    required RepositoryQuery query,
    required String jobId,
  }) =>
      _api.executeYearTransition(query: query, jobId: jobId);

  @override
  Future<AcademicTransitionJob> getTransitionJob({
    required RepositoryQuery query,
    required String jobId,
  }) =>
      _api.getTransitionJob(query: query, jobId: jobId);

  @override
  Future<ReshufflePlan> previewStudentReshuffle({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    required String strategy,
  }) =>
      _api.previewStudentReshuffle(
        query: query,
        classLabel: classLabel,
        academicYear: academicYear,
        strategy: strategy,
      );

  @override
  Future<AcademicOperationExecutionReport> executeStudentReshuffle({
    required RepositoryQuery query,
    required String planId,
  }) =>
      _api.executeStudentReshuffle(query: query, planId: planId);

  @override
  Future<SectionBalancePlan> previewSectionBalance({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    int? targetSize,
  }) =>
      _api.previewSectionBalance(
        query: query,
        classLabel: classLabel,
        academicYear: academicYear,
        targetSize: targetSize,
      );

  @override
  Future<AcademicOperationExecutionReport> executeSectionBalance({
    required RepositoryQuery query,
    required String planId,
  }) =>
      _api.executeSectionBalance(query: query, planId: planId);

  @override
  Future<QuarterlyReshufflePlan> previewQuarterlyReshuffle({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    required int quarter,
  }) =>
      _api.previewQuarterlyReshuffle(
        query: query,
        classLabel: classLabel,
        academicYear: academicYear,
        quarter: quarter,
      );

  @override
  Future<AcademicOperationExecutionReport> executeQuarterlyReshuffle({
    required RepositoryQuery query,
    required String planId,
  }) =>
      _api.executeQuarterlyReshuffle(query: query, planId: planId);

  @override
  Future<PerformanceBalancePlan> previewPerformanceBalance({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
  }) =>
      _api.previewPerformanceBalance(
        query: query,
        classLabel: classLabel,
        academicYear: academicYear,
      );

  @override
  Future<AcademicOperationExecutionReport> executePerformanceBalance({
    required RepositoryQuery query,
    required String planId,
  }) =>
      _api.executePerformanceBalance(query: query, planId: planId);
}
