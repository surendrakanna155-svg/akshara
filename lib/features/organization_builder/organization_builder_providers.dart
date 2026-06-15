import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import 'organization_builder_models.dart';

final organizationBuilderQueryProvider = Provider((ref) {
  return ref.watch(repositoryQueryProvider);
});

final verticalPacksProvider = FutureProvider<List<VerticalPack>>((ref) async {
  return ref.read(organizationBuilderRepositoryProvider).listVerticalPacks(
        query: ref.watch(organizationBuilderQueryProvider),
      );
});

final interviewDraftsProvider =
    FutureProvider<List<InterviewDraft>>((ref) async {
  return ref.read(organizationBuilderRepositoryProvider).listInterviewDrafts(
        query: ref.watch(organizationBuilderQueryProvider),
      );
});

final interviewDraftProvider =
    FutureProvider.family<InterviewDraft, String>((ref, draftId) async {
  return ref.read(organizationBuilderRepositoryProvider).getInterviewDraft(
        query: ref.watch(organizationBuilderQueryProvider),
        draftId: draftId,
      );
});

final configPreviewProvider =
    FutureProvider.family<ConfigPreview, String>((ref, draftId) async {
  return ref.read(organizationBuilderRepositoryProvider).generatePreview(
        query: ref.watch(organizationBuilderQueryProvider),
        draftId: draftId,
      );
});

final provisioningJobProvider =
    FutureProvider.family<ProvisioningJob, String>((ref, jobId) async {
  return ref.read(organizationBuilderRepositoryProvider).getProvisioningJob(
        query: ref.watch(organizationBuilderQueryProvider),
        jobId: jobId,
      );
});
