import '../../interfaces/sis_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/sis/sis_models.dart';
import '../../../../features/sis/sis_requests.dart';
import 'api_sis_repository.dart';

/// Thin wrapper routing all SIS operations to [ApiSisRepository].
class HybridSisRepository implements SisRepository {
  HybridSisRepository({required ApiSisRepository api}) : _api = api;

  final ApiSisRepository _api;

  @override
  Future<SisDashboardData> getDashboard({required RepositoryQuery query}) =>
      _api.getDashboard(query: query);

  @override
  Future<PaginatedResult<SisStudent>> getStudents({
    required RepositoryQuery query,
  }) =>
      _api.getStudents(query: query);

  @override
  Future<SisStudentProfile> getStudentProfile({
    required RepositoryQuery query,
    required String studentId,
  }) =>
      _api.getStudentProfile(query: query, studentId: studentId);

  @override
  Future<SisAcademicAssignmentData> getAcademicAssignment({
    required RepositoryQuery query,
  }) =>
      _api.getAcademicAssignment(query: query);

  @override
  Future<SisAdmissionsConversionData> getAdmissionsConversion({
    required RepositoryQuery query,
  }) =>
      _api.getAdmissionsConversion(query: query);

  @override
  Future<SisStudent> createStudent({
    required RepositoryQuery query,
    required CreateStudentRequest request,
  }) =>
      _api.createStudent(query: query, request: request);

  @override
  Future<SisStudent> updateStudent({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentRequest request,
  }) =>
      _api.updateStudent(
        query: query,
        studentId: studentId,
        request: request,
      );

  @override
  Future<SisDocumentSummary> uploadStudentDocument({
    required RepositoryQuery query,
    required String studentId,
    required UploadStudentDocumentRequest request,
  }) =>
      _api.uploadStudentDocument(
        query: query,
        studentId: studentId,
        request: request,
      );

  @override
  Future<SisStudent> updateStudentStatus({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentStatusRequest request,
  }) =>
      _api.updateStudentStatus(
        query: query,
        studentId: studentId,
        request: request,
      );

  @override
  Future<SisStudent> assignAcademicAssignment({
    required RepositoryQuery query,
    required AcademicAssignmentRequest request,
  }) =>
      _api.assignAcademicAssignment(query: query, request: request);

  @override
  Future<SisConversionPreview> convertAdmissionsEnrollment({
    required RepositoryQuery query,
    required AdmissionsConversionRequest request,
  }) =>
      _api.convertAdmissionsEnrollment(query: query, request: request);
}
