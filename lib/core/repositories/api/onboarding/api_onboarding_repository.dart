import '../../interfaces/onboarding_repository.dart';
import '../../repository_query.dart';
import '../../../../features/onboarding/onboarding_models.dart';
import 'mapper/onboarding_mapper.dart';
import 'remote/onboarding_remote_datasource.dart';

class ApiOnboardingRepository implements OnboardingRepository {
  ApiOnboardingRepository({
    required OnboardingRemoteDataSource remote,
    OnboardingMapper mapper = const OnboardingMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final OnboardingRemoteDataSource _remote;
  final OnboardingMapper _mapper;

  @override
  Future<OnboardingDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<OnboardingImportPreviewResult> previewStudentImport({
    required RepositoryQuery query,
    required String fileName,
    required List<Map<String, dynamic>> rows,
  }) async {
    final dto = await _remote.previewStudentImport(
      query: query,
      fileName: fileName,
      rows: rows,
    );
    return _mapper.toPreview(dto);
  }

  @override
  Future<OnboardingImportPreviewResult> previewTeacherImport({
    required RepositoryQuery query,
    required String fileName,
    required List<Map<String, dynamic>> rows,
  }) async {
    final dto = await _remote.previewTeacherImport(
      query: query,
      fileName: fileName,
      rows: rows,
    );
    return _mapper.toPreview(dto);
  }

  @override
  Future<OnboardingImportJob> commitImport({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final dto = await _remote.commitImport(query: query, jobId: jobId);
    return _mapper.toJob(dto);
  }

  @override
  Future<OnboardingImportJob> rollbackImport({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final dto = await _remote.rollbackImport(query: query, jobId: jobId);
    return _mapper.toJob(dto);
  }

  @override
  Future<OnboardingImportJob> generatePlaceholderStudents({
    required RepositoryQuery query,
    required String academicYear,
    required List<ClassSectionStructure> classes,
  }) async {
    final dto = await _remote.generatePlaceholderStudents(
      query: query,
      academicYear: academicYear,
      classes: [for (final c in classes) c.toJson()],
    );
    return _mapper.toGeneratedJob(dto);
  }

  @override
  Future<List<OnboardingImportJob>> listImportJobs({required RepositoryQuery query}) async {
    final dashboard = await getDashboard(query: query);
    return dashboard.recentJobs;
  }

  @override
  Future<OnboardingInvite> createInvite({
    required RepositoryQuery query,
    required String inviteType,
    required String recipientPhone,
    required String recipientLabel,
    String? studentId,
    String channel = 'whatsapp',
  }) async {
    final dto = await _remote.createInvite(
      query: query,
      inviteType: inviteType,
      recipientPhone: recipientPhone,
      recipientLabel: recipientLabel,
      studentId: studentId,
      channel: channel,
    );
    return _mapper.toInvite(dto);
  }

  @override
  Future<List<OnboardingInvite>> listInvites({required RepositoryQuery query}) async {
    final dto = await _remote.fetchInvites(query: query);
    return _mapper.toInvites(dto);
  }
}
