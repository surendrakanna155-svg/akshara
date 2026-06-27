import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'organization_builder_models.dart';
import 'organization_builder_providers.dart';

void assertManageOrganizationBuilder(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null ||
      !permissions.has(Permission.manageOrganizationBuilder)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message:
            'You do not have permission to manage the organization builder.',
        code: 'RBAC_MANAGE_ORGANIZATION_BUILDER',
      ),
    );
  }
}

void _invalidateOrganizationBuilderReads(Ref ref, {String? draftId}) {
  ref.invalidate(interviewDraftsProvider);
  if (draftId != null) {
    ref.invalidate(interviewDraftProvider(draftId));
    ref.invalidate(configPreviewProvider(draftId));
  }
}

class SaveInterviewStepNotifier extends AsyncNotifier<InterviewDraft?> {
  @override
  FutureOr<InterviewDraft?> build() => null;

  Future<InterviewDraft?> execute({
    required String draftId,
    required int stepIndex,
    required Map<String, String> answers,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageOrganizationBuilder(ref);
      try {
        final result = await ref
            .read(organizationBuilderRepositoryProvider)
            .saveInterviewStep(
              query: ref.read(repositoryQueryProvider),
              draftId: draftId,
              stepIndex: stepIndex,
              answers: answers,
            );
        _invalidateOrganizationBuilderReads(ref, draftId: draftId);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final saveInterviewStepProvider =
    AsyncNotifierProvider<SaveInterviewStepNotifier, InterviewDraft?>(
  SaveInterviewStepNotifier.new,
);

class GeneratePreviewNotifier extends AsyncNotifier<ConfigPreview?> {
  @override
  FutureOr<ConfigPreview?> build() => null;

  Future<ConfigPreview?> execute({required String draftId}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageOrganizationBuilder(ref);
      try {
        final result = await ref
            .read(organizationBuilderRepositoryProvider)
            .generatePreview(
              query: ref.read(repositoryQueryProvider),
              draftId: draftId,
            );
        _invalidateOrganizationBuilderReads(ref, draftId: draftId);
        ref.invalidate(configPreviewProvider(draftId));
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final generatePreviewProvider =
    AsyncNotifierProvider<GeneratePreviewNotifier, ConfigPreview?>(
  GeneratePreviewNotifier.new,
);

class StartProvisioningNotifier extends AsyncNotifier<ProvisioningJob?> {
  @override
  FutureOr<ProvisioningJob?> build() => null;

  Future<ProvisioningJob?> execute({required String draftId}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageOrganizationBuilder(ref);
      try {
        final result = await ref
            .read(organizationBuilderRepositoryProvider)
            .startProvisioning(
              query: ref.read(repositoryQueryProvider),
              draftId: draftId,
            );
        _invalidateOrganizationBuilderReads(ref, draftId: draftId);
        ref.invalidate(provisioningJobProvider(result.id));
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final startProvisioningProvider =
    AsyncNotifierProvider<StartProvisioningNotifier, ProvisioningJob?>(
  StartProvisioningNotifier.new,
);
