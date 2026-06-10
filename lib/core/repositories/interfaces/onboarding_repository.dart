import '../repository_query.dart';
import '../../../features/onboarding/onboarding_models.dart';

abstract class OnboardingRepository {
  Future<OnboardingDashboardData> getDashboard({required RepositoryQuery query});

  Future<OnboardingImportPreviewResult> previewStudentImport({
    required RepositoryQuery query,
    required String fileName,
    required List<Map<String, dynamic>> rows,
  });

  Future<OnboardingImportPreviewResult> previewTeacherImport({
    required RepositoryQuery query,
    required String fileName,
    required List<Map<String, dynamic>> rows,
  });

  Future<OnboardingImportJob> commitImport({
    required RepositoryQuery query,
    required String jobId,
  });

  Future<OnboardingImportJob> rollbackImport({
    required RepositoryQuery query,
    required String jobId,
  });

  Future<List<OnboardingImportJob>> listImportJobs({required RepositoryQuery query});

  Future<OnboardingInvite> createInvite({
    required RepositoryQuery query,
    required String inviteType,
    required String recipientPhone,
    required String recipientLabel,
    String? studentId,
    String channel = 'whatsapp',
  });

  Future<List<OnboardingInvite>> listInvites({required RepositoryQuery query});
}
