import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'workflow_automation_providers.dart';

void assertManageWorkflowAutomation(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  final canManage = permissions?.has(Permission.manageWorkflowAutomation) == true ||
      permissions?.has(Permission.manageManagement) == true;
  if (!canManage) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'Workflow automation manage permission required.',
        code: 'RBAC_MANAGE_WORKFLOW_AUTOMATION',
      ),
    );
  }
}

class WorkflowAutomationMutations extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> executeAction({
    required String instanceId,
    required String transitionAction,
  }) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageWorkflowAutomation(ref);
      await ref.read(workflowRepositoryProvider).executeAction(
            query: ref.read(repositoryQueryProvider),
            instanceId: instanceId,
            transitionAction: transitionAction,
          );
      ref.invalidate(workflowInstancesProvider);
    });
  }

  Future<void> runScheduledJobsNow() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageWorkflowAutomation(ref);
      await ref.read(workflowRepositoryProvider).runScheduledJobs(
            query: ref.read(repositoryQueryProvider),
            now: DateTime.now(),
          );
      ref
        ..invalidate(workflowInstancesProvider)
        ..invalidate(scheduledWorkflowJobsProvider);
    });
  }
}

final workflowAutomationMutationsProvider =
    AsyncNotifierProvider<WorkflowAutomationMutations, void>(
  WorkflowAutomationMutations.new,
);
