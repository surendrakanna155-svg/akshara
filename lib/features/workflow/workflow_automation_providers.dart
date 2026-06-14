import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../core/workflow/workflow_models.dart';

final workflowDefinitionsProvider = FutureProvider<List<WorkflowDefinition>>((ref) async {
  return ref.read(workflowRepositoryProvider).listDefinitions(
        query: ref.watch(repositoryQueryProvider),
      );
});

final workflowInstancesProvider = FutureProvider<List<WorkflowInstance>>((ref) async {
  return ref.read(workflowRepositoryProvider).listInstances(
        query: ref.watch(repositoryQueryProvider),
      );
});

final scheduledWorkflowJobsProvider = FutureProvider<List<ScheduledWorkflowJob>>((ref) async {
  return ref.read(workflowRepositoryProvider).listScheduledJobs(
        query: ref.watch(repositoryQueryProvider),
      );
});

final escalatedWorkflowInstancesProvider = Provider<List<WorkflowInstance>>((ref) {
  final instances = ref.watch(workflowInstancesProvider).valueOrNull ?? const <WorkflowInstance>[];
  return instances.where((instance) => instance.status == WorkflowInstanceStatus.escalated).toList(growable: false);
});
