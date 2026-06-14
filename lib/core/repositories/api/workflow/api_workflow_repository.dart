import '../../interfaces/workflow_repository.dart';
import '../../repository_query.dart';
import '../../../workflow/workflow_models.dart';
import 'dto/workflow_request_dto.dart';
import 'mapper/workflow_mapper.dart';
import 'remote/workflow_remote_datasource.dart';

class ApiWorkflowRepository implements WorkflowRepository {
  ApiWorkflowRepository({
    required WorkflowRemoteDataSource remote,
    WorkflowMapper mapper = const WorkflowMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final WorkflowRemoteDataSource _remote;
  final WorkflowMapper _mapper;

  @override
  Future<void> deleteDefinition({
    required RepositoryQuery query,
    required String definitionId,
  }) =>
      _remote.deleteDefinition(query: query, definitionId: definitionId);

  @override
  Future<WorkflowInstance> executeAction({
    required RepositoryQuery query,
    required String instanceId,
    required String transitionAction,
    String? actorRole,
  }) async {
    final data = await _remote.executeAction(
      query: query,
      instanceId: instanceId,
      request: WorkflowActionRequestDto(
        transitionAction: transitionAction,
        actorRole: actorRole,
      ),
    );
    return _mapper.instanceFromJson(data['instance'] as Map<String, dynamic>? ?? data);
  }

  @override
  Future<List<WorkflowDefinition>> listDefinitions({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.listDefinitions(query: query);
    return rows.map(_mapper.definitionFromJson).toList(growable: false);
  }

  @override
  Future<List<WorkflowInstance>> listInstances({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.listInstances(query: query);
    return rows.map(_mapper.instanceFromJson).toList(growable: false);
  }

  @override
  Future<List<ScheduledWorkflowJob>> listScheduledJobs({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.listScheduledJobs(query: query);
    return rows.map(_mapper.jobFromJson).toList(growable: false);
  }

  @override
  Future<List<WorkflowInstance>> runScheduledJobs({
    required RepositoryQuery query,
    required DateTime now,
  }) async {
    final rows = await _remote.runScheduledJobs(query: query, now: now);
    return rows.map(_mapper.instanceFromJson).toList(growable: false);
  }

  @override
  Future<ScheduledWorkflowJob> scheduleJob({
    required RepositoryQuery query,
    required ScheduledWorkflowJob job,
  }) async {
    final data = await _remote.scheduleJob(
      query: query,
      job: _mapper.jobToJson(job),
    );
    return _mapper.jobFromJson(data['job'] as Map<String, dynamic>? ?? data);
  }

  @override
  Future<WorkflowInstance?> triggerWorkflow({
    required RepositoryQuery query,
    required WorkflowTriggerType triggerType,
    required Map<String, Object?> payload,
  }) async {
    final instance = await _remote.triggerWorkflow(
      query: query,
      request: WorkflowTriggerRequestDto(
        triggerType: triggerType,
        payload: payload,
      ),
    );
    if (instance == null) return null;
    return _mapper.instanceFromJson(instance);
  }

  @override
  Future<WorkflowDefinition> upsertDefinition({
    required RepositoryQuery query,
    required WorkflowDefinition definition,
  }) async {
    final data = await _remote.upsertDefinition(
      query: query,
      definition: _mapper.definitionToJson(definition),
    );
    return _mapper.definitionFromJson(data['definition'] as Map<String, dynamic>? ?? data);
  }
}
