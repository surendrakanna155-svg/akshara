import '../../interfaces/sis_repository.dart';
import '../../repository_query.dart';
import '../../../../features/sis/sis_models.dart';
import '../../../../features/sis/sis_requests.dart';
import 'mapper/sis_mapper.dart';
import 'remote/sis_remote_datasource.dart';

/// API implementation of [SisRepository] — enabled via [sisApiEnabledProvider].
class ApiSisRepository implements SisRepository {
  ApiSisRepository({
    required SisRemoteDataSource remote,
    SisMapper mapper = const SisMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final SisRemoteDataSource _remote;
  final SisMapper _mapper;

  @override
  Future<SisDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<List<SisStudent>> getStudents({required RepositoryQuery query}) async {
    final dto = await _remote.fetchStudents(query: query);
    return _mapper.toStudents(dto);
  }

  @override
  Future<SisStudentProfile> getStudentProfile({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final dto = await _remote.fetchStudentProfile(
      query: query,
      studentId: studentId,
    );
    return _mapper.toStudentProfile(dto);
  }

  @override
  Future<SisAcademicAssignmentData> getAcademicAssignment({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAcademicAssignment(query: query);
    return _mapper.toAcademicAssignment(dto);
  }

  @override
  Future<SisAdmissionsConversionData> getAdmissionsConversion({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAdmissionsConversion(query: query);
    return _mapper.toAdmissionsConversion(dto);
  }

  @override
  Future<SisStudent> createStudent({
    required RepositoryQuery query,
    required CreateStudentRequest request,
  }) async {
    return _remote.createStudent(query: query, request: request);
  }

  @override
  Future<SisStudent> updateStudent({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentRequest request,
  }) async {
    return _remote.updateStudent(
      query: query,
      studentId: studentId,
      request: request,
    );
  }

  @override
  Future<SisStudent> updateStudentStatus({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentStatusRequest request,
  }) async {
    return _remote.updateStudentStatus(
      query: query,
      studentId: studentId,
      request: request,
    );
  }

  @override
  Future<SisStudent> assignAcademicAssignment({
    required RepositoryQuery query,
    required AcademicAssignmentRequest request,
  }) async {
    return _remote.assignAcademicAssignment(query: query, request: request);
  }

  @override
  Future<SisConversionPreview> convertAdmissionsEnrollment({
    required RepositoryQuery query,
    required AdmissionsConversionRequest request,
  }) async {
    return _remote.convertAdmissionsEnrollment(query: query, request: request);
  }
}
