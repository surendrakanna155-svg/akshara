import '../../workflow/workflow_models.dart';
import '../repository_query.dart';

abstract class WorkflowRepository {
  Future<List<WorkflowDefinition>> listDefinitions({
    required RepositoryQuery query,
  });

  Future<WorkflowDefinition> upsertDefinition({
    required RepositoryQuery query,
    required WorkflowDefinition definition,
  });

  Future<void> deleteDefinition({
    required RepositoryQuery query,
    required String definitionId,
  });

  Future<List<WorkflowInstance>> listInstances({
    required RepositoryQuery query,
  });

  Future<WorkflowInstance?> triggerWorkflow({
    required RepositoryQuery query,
    required WorkflowTriggerType triggerType,
    required Map<String, Object?> payload,
  });

  Future<WorkflowInstance> executeAction({
    required RepositoryQuery query,
    required String instanceId,
    required String transitionAction,
    String? actorRole,
  });

  Future<List<ScheduledWorkflowJob>> listScheduledJobs({
    required RepositoryQuery query,
  });

  Future<ScheduledWorkflowJob> scheduleJob({
    required RepositoryQuery query,
    required ScheduledWorkflowJob job,
  });

  Future<List<WorkflowInstance>> runScheduledJobs({
    required RepositoryQuery query,
    required DateTime now,
  });
}
