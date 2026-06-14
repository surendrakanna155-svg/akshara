import '../../interfaces/workflow_repository.dart';
import '../../repository_query.dart';
import '../../../workflow/workflow_models.dart';
import 'api_workflow_repository.dart';

class HybridWorkflowRepository implements WorkflowRepository {
  HybridWorkflowRepository({required ApiWorkflowRepository api}) : _api = api;

  final ApiWorkflowRepository _api;

  @override
  Future<void> deleteDefinition({
    required RepositoryQuery query,
    required String definitionId,
  }) =>
      _api.deleteDefinition(query: query, definitionId: definitionId);

  @override
  Future<WorkflowInstance> executeAction({
    required RepositoryQuery query,
    required String instanceId,
    required String transitionAction,
    String? actorRole,
  }) =>
      _api.executeAction(
        query: query,
        instanceId: instanceId,
        transitionAction: transitionAction,
        actorRole: actorRole,
      );

  @override
  Future<List<WorkflowDefinition>> listDefinitions({
    required RepositoryQuery query,
  }) =>
      _api.listDefinitions(query: query);

  @override
  Future<List<WorkflowInstance>> listInstances({
    required RepositoryQuery query,
  }) =>
      _api.listInstances(query: query);

  @override
  Future<List<ScheduledWorkflowJob>> listScheduledJobs({
    required RepositoryQuery query,
  }) =>
      _api.listScheduledJobs(query: query);

  @override
  Future<List<WorkflowInstance>> runScheduledJobs({
    required RepositoryQuery query,
    required DateTime now,
  }) =>
      _api.runScheduledJobs(query: query, now: now);

  @override
  Future<ScheduledWorkflowJob> scheduleJob({
    required RepositoryQuery query,
    required ScheduledWorkflowJob job,
  }) =>
      _api.scheduleJob(query: query, job: job);

  @override
  Future<WorkflowInstance?> triggerWorkflow({
    required RepositoryQuery query,
    required WorkflowTriggerType triggerType,
    required Map<String, Object?> payload,
  }) =>
      _api.triggerWorkflow(
        query: query,
        triggerType: triggerType,
        payload: payload,
      );

  @override
  Future<WorkflowDefinition> upsertDefinition({
    required RepositoryQuery query,
    required WorkflowDefinition definition,
  }) =>
      _api.upsertDefinition(query: query, definition: definition);
}
