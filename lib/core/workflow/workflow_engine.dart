import 'workflow_models.dart';

class WorkflowEngine {
  const WorkflowEngine({DateTime Function()? now}) : _now = now;

  final DateTime Function()? _now;

  DateTime get _clock => _now?.call() ?? DateTime.now();

  bool evaluateRules(
    WorkflowDefinition definition,
    Map<String, Object?> context,
  ) {
    for (final rule in definition.rules.where((r) => r.enabled)) {
      final value = context[rule.field];
      if (!_evaluateRule(rule.operator, value, rule.value)) {
        return false;
      }
    }
    return true;
  }

  WorkflowInstance? executeTrigger({
    required WorkflowDefinition definition,
    required WorkflowTriggerType triggerType,
    required Map<String, Object?> payload,
  }) {
    WorkflowTrigger? trigger;
    for (final candidate in definition.triggers) {
      if (candidate.type == triggerType) {
        trigger = candidate;
        break;
      }
    }
    if (trigger == null || !definition.enabled) {
      return null;
    }
    if (!evaluateRules(definition, payload)) {
      return null;
    }
    final now = _clock;
    return WorkflowInstance(
      id: '${definition.id}-${now.microsecondsSinceEpoch}',
      definitionId: definition.id,
      status: WorkflowInstanceStatus.queued,
      createdAt: now,
      updatedAt: now,
      currentAssigneeRole: 'operations',
      payload: payload,
      auditTrail: <String>['Triggered by ${trigger.type.name}'],
    );
  }

  WorkflowInstance applyTransition({
    required WorkflowInstance instance,
    required WorkflowTransition transition,
    String? actorRole,
  }) {
    if (instance.status != transition.fromStatus) {
      return instance;
    }
    final now = _clock;
    final nextStatus = transition.autoApprove ? WorkflowInstanceStatus.approved : transition.toStatus;
    final nextRole = transition.autoRouteToRole ?? actorRole ?? instance.currentAssigneeRole;
    final updatedTrail = <String>[
      ...instance.auditTrail,
      'Transition ${transition.action} -> ${nextStatus.name}',
    ];
    return instance.copyWith(
      status: nextStatus,
      updatedAt: now,
      currentAssigneeRole: nextRole,
      auditTrail: updatedTrail,
    );
  }

  WorkflowInstance escalate({
    required WorkflowInstance instance,
    required EscalationPolicy policy,
  }) {
    final now = _clock;
    if (instance.escalationLevel >= policy.maxEscalationLevel) {
      return instance;
    }
    return instance.copyWith(
      status: WorkflowInstanceStatus.escalated,
      updatedAt: now,
      currentAssigneeRole: policy.escalateToRole,
      escalationLevel: instance.escalationLevel + 1,
      lastEscalatedAt: now,
      auditTrail: <String>[
        ...instance.auditTrail,
        'Escalated to ${policy.escalateToRole}',
      ],
    );
  }

  List<WorkflowInstance> runScheduledJobs({
    required List<WorkflowDefinition> definitions,
    required List<ScheduledWorkflowJob> jobs,
    required DateTime now,
  }) {
    final definitionById = <String, WorkflowDefinition>{
      for (final definition in definitions) definition.id: definition,
    };
    final instances = <WorkflowInstance>[];
    for (final job in jobs.where((j) => j.enabled && !j.scheduledAt.isAfter(now))) {
      final definition = definitionById[job.definitionId];
      if (definition == null) continue;
      final instance = executeTrigger(
        definition: definition,
        triggerType: WorkflowTriggerType.scheduled,
        payload: <String, Object?>{
          ...job.payload,
          'scheduledJobId': job.id,
          'scheduledAt': job.scheduledAt.toIso8601String(),
        },
      );
      if (instance != null) {
        instances.add(instance);
      }
    }
    return instances;
  }

  bool _evaluateRule(
    WorkflowRuleOperator operator,
    Object? left,
    Object? right,
  ) {
    return switch (operator) {
      WorkflowRuleOperator.equals => left == right,
      WorkflowRuleOperator.notEquals => left != right,
      WorkflowRuleOperator.contains => left is Iterable ? left.contains(right) : '$left'.contains('$right'),
      WorkflowRuleOperator.greaterThan => _asNum(left) > _asNum(right),
      WorkflowRuleOperator.lessThan => _asNum(left) < _asNum(right),
    };
  }

  num _asNum(Object? value) {
    if (value is num) return value;
    return num.tryParse('$value') ?? 0;
  }
}
