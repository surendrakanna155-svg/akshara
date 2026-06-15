import '../../../features/organization_builder/organization_builder_models.dart';
import '../repository_query.dart';

abstract class OrganizationBuilderRepository {
  Future<List<VerticalPack>> listVerticalPacks({
    required RepositoryQuery query,
  });

  Future<List<InterviewDraft>> listInterviewDrafts({
    required RepositoryQuery query,
  });

  Future<InterviewDraft> getInterviewDraft({
    required RepositoryQuery query,
    required String draftId,
  });

  Future<InterviewDraft> saveInterviewStep({
    required RepositoryQuery query,
    required String draftId,
    required int stepIndex,
    required Map<String, String> answers,
  });

  Future<ConfigPreview> generatePreview({
    required RepositoryQuery query,
    required String draftId,
  });

  Future<ProvisioningJob> startProvisioning({
    required RepositoryQuery query,
    required String draftId,
  });

  Future<ProvisioningJob> getProvisioningJob({
    required RepositoryQuery query,
    required String jobId,
  });
}
