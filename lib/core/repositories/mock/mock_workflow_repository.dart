import '../../workflow/workflow_engine.dart';
import '../../workflow/workflow_models.dart';
import '../../workflow/workflow_registry.dart';
import '../interfaces/workflow_repository.dart';
import '../repository_query.dart';

class MockWorkflowRepository implements WorkflowRepository {
  MockWorkflowRepository({WorkflowEngine? engine}) : _engine = engine ?? const WorkflowEngine() {
    final seeded = WorkflowRegistry.seedSchoolPackDefinitions();
    for (final definition in seeded) {
      _definitions[definition.id] = definition;
    }
  }

  final WorkflowEngine _engine;
  final Map<String, WorkflowDefinition> _definitions = <String, WorkflowDefinition>{};
  final Map<String, WorkflowInstance> _instances = <String, WorkflowInstance>{};
  final Map<String, ScheduledWorkflowJob> _jobs = <String, ScheduledWorkflowJob>{};

  @override
  Future<void> deleteDefinition({
    required RepositoryQuery query,
    required String definitionId,
  }) async {
    _definitions.remove(definitionId);
  }

  @override
  Future<WorkflowInstance> executeAction({
    required RepositoryQuery query,
    required String instanceId,
    required String transitionAction,
    String? actorRole,
  }) async {
    final instance = _instances[instanceId];
    if (instance == null) {
      throw StateError('Workflow instance not found: $instanceId');
    }
    final definition = _definitions[instance.definitionId];
    if (definition == null) {
      throw StateError('Workflow definition not found: ${instance.definitionId}');
    }
    WorkflowTransition? transition;
    for (final candidate in definition.transitions) {
      if (candidate.action == transitionAction) {
        transition = candidate;
        break;
      }
    }
    if (transition == null) {
      throw StateError('Transition not found: $transitionAction');
    }
    final updated = _engine.applyTransition(
      instance: instance,
      transition: transition,
      actorRole: actorRole,
    );
    _instances[updated.id] = updated;
    return updated;
  }

  @override
  Future<List<WorkflowDefinition>> listDefinitions({
    required RepositoryQuery query,
  }) async {
    return _definitions.values.toList(growable: false);
  }

  @override
  Future<List<WorkflowInstance>> listInstances({
    required RepositoryQuery query,
  }) async {
    final sorted = _instances.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  @override
  Future<List<ScheduledWorkflowJob>> listScheduledJobs({
    required RepositoryQuery query,
  }) async {
    final sorted = _jobs.values.toList(growable: false)
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return sorted;
  }

  @override
  Future<List<WorkflowInstance>> runScheduledJobs({
    required RepositoryQuery query,
    required DateTime now,
  }) async {
    final instances = _engine.runScheduledJobs(
      definitions: _definitions.values.toList(growable: false),
      jobs: _jobs.values.toList(growable: false),
      now: now,
    );
    for (final instance in instances) {
      _instances[instance.id] = instance;
    }
    for (final job in _jobs.values.toList(growable: false)) {
      if (!job.enabled || job.scheduledAt.isAfter(now)) continue;
      _jobs[job.id] = job.copyWith(lastRunAt: now);
    }
    return instances;
  }

  @override
  Future<ScheduledWorkflowJob> scheduleJob({
    required RepositoryQuery query,
    required ScheduledWorkflowJob job,
  }) async {
    _jobs[job.id] = job;
    return job;
  }

  @override
  Future<WorkflowInstance?> triggerWorkflow({
    required RepositoryQuery query,
    required WorkflowTriggerType triggerType,
    required Map<String, Object?> payload,
  }) async {
    for (final definition in _definitions.values.where((d) => d.enabled)) {
      final instance = _engine.executeTrigger(
        definition: definition,
        triggerType: triggerType,
        payload: payload,
      );
      if (instance != null) {
        _instances[instance.id] = instance;
        return instance;
      }
    }
    return null;
  }

  @override
  Future<WorkflowDefinition> upsertDefinition({
    required RepositoryQuery query,
    required WorkflowDefinition definition,
  }) async {
    _definitions[definition.id] = definition;
    return definition;
  }
}
