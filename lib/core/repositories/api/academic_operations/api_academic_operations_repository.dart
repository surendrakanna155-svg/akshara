import '../../interfaces/academic_operations_repository.dart';
import '../../repository_query.dart';
import '../../../../features/sis/academic_operations/academic_operations_models.dart';
import 'dto/academic_operations_request_dto.dart';
import 'mapper/academic_operations_mapper.dart';
import 'remote/academic_operations_remote_datasource.dart';

class ApiAcademicOperationsRepository implements AcademicOperationsRepository {
  ApiAcademicOperationsRepository({
    required AcademicOperationsRemoteDataSource remote,
    AcademicOperationsMapper mapper = const AcademicOperationsMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final AcademicOperationsRemoteDataSource _remote;
  final AcademicOperationsMapper _mapper;

  @override
  Future<List<ClassMappingRule>> suggestClassMappings({
    required RepositoryQuery query,
    required String sourceYearId,
    required String targetYearId,
  }) async {
    final rows = await _remote.suggestClassMappings(
      query: query,
      sourceYearId: sourceYearId,
      targetYearId: targetYearId,
    );
    return _mapper.toMappingRules(rows);
  }

  @override
  Future<AcademicTransitionJob> previewYearTransition({
    required RepositoryQuery query,
    required String sourceYearId,
    required String targetYearId,
    required List<ClassMappingRule> mappings,
  }) async {
    final dto = await _remote.previewYearTransition(
      query: query,
      sourceYearId: sourceYearId,
      targetYearId: targetYearId,
      mappings: mappings
          .map((rule) => ClassMappingRuleDto.fromDomain(rule))
          .toList(growable: false),
    );
    return _mapper.toTransitionJob(dto);
  }

  @override
  Future<AcademicTransitionExecutionReport> executeYearTransition({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final dto = await _remote.executeYearTransition(query: query, jobId: jobId);
    return _mapper.toTransitionExecutionReport(dto);
  }

  @override
  Future<AcademicTransitionJob> getTransitionJob({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final dto = await _remote.getTransitionJob(query: query, jobId: jobId);
    return _mapper.toTransitionJob(dto);
  }

  @override
  Future<ReshufflePlan> previewStudentReshuffle({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    required String strategy,
  }) async {
    final dto = await _remote.previewStudentReshuffle(
      query: query,
      classLabel: classLabel,
      academicYear: academicYear,
      strategy: strategy,
    );
    return _mapper.toReshufflePlan(dto);
  }

  @override
  Future<AcademicOperationExecutionReport> executeStudentReshuffle({
    required RepositoryQuery query,
    required String planId,
  }) async {
    final dto = await _remote.executeStudentReshuffle(query: query, planId: planId);
    return _mapper.toExecutionReport(dto);
  }

  @override
  Future<SectionBalancePlan> previewSectionBalance({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    int? targetSize,
  }) async {
    final dto = await _remote.previewSectionBalance(
      query: query,
      classLabel: classLabel,
      academicYear: academicYear,
      targetSize: targetSize,
    );
    return _mapper.toSectionBalancePlan(dto);
  }

  @override
  Future<AcademicOperationExecutionReport> executeSectionBalance({
    required RepositoryQuery query,
    required String planId,
  }) async {
    final dto = await _remote.executeSectionBalance(query: query, planId: planId);
    return _mapper.toExecutionReport(dto);
  }

  @override
  Future<QuarterlyReshufflePlan> previewQuarterlyReshuffle({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    required int quarter,
  }) async {
    final dto = await _remote.previewQuarterlyReshuffle(
      query: query,
      classLabel: classLabel,
      academicYear: academicYear,
      quarter: quarter,
    );
    return _mapper.toQuarterlyPlan(dto);
  }

  @override
  Future<AcademicOperationExecutionReport> executeQuarterlyReshuffle({
    required RepositoryQuery query,
    required String planId,
  }) async {
    final dto = await _remote.executeQuarterlyReshuffle(
      query: query,
      planId: planId,
    );
    return _mapper.toExecutionReport(dto);
  }

  @override
  Future<PerformanceBalancePlan> previewPerformanceBalance({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
  }) async {
    final dto = await _remote.previewPerformanceBalance(
      query: query,
      classLabel: classLabel,
      academicYear: academicYear,
    );
    return _mapper.toPerformancePlan(dto);
  }

  @override
  Future<AcademicOperationExecutionReport> executePerformanceBalance({
    required RepositoryQuery query,
    required String planId,
  }) async {
    final dto = await _remote.executePerformanceBalance(
      query: query,
      planId: planId,
    );
    return _mapper.toExecutionReport(dto);
  }
}
