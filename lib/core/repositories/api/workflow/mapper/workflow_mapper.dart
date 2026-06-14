import '../../../../workflow/workflow_models.dart';

class WorkflowMapper {
  const WorkflowMapper();

  WorkflowDefinition definitionFromJson(Map<String, dynamic> json) {
    return WorkflowDefinition(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      module: json['module'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      rules: _list(json['rules']).map(_ruleFromJson).toList(growable: false),
      triggers: _list(json['triggers']).map(_triggerFromJson).toList(growable: false),
      transitions: _list(json['transitions']).map(_transitionFromJson).toList(growable: false),
      escalationPolicy: json['escalationPolicy'] is Map<String, dynamic>
          ? _escalationFromJson(json['escalationPolicy'] as Map<String, dynamic>)
          : null,
    );
  }

  WorkflowInstance instanceFromJson(Map<String, dynamic> json) {
    return WorkflowInstance(
      id: json['id'] as String? ?? '',
      definitionId: json['definitionId'] as String? ?? '',
      status: _status(json['status'] as String? ?? 'queued'),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      currentAssigneeRole: json['currentAssigneeRole'] as String? ?? 'operations',
      payload: (json['payload'] as Map?)?.cast<String, Object?>() ?? const <String, Object?>{},
      escalationLevel: (json['escalationLevel'] as num?)?.toInt() ?? 0,
      lastEscalatedAt: DateTime.tryParse(json['lastEscalatedAt'] as String? ?? ''),
      auditTrail: (json['auditTrail'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => '$entry')
          .toList(growable: false),
    );
  }

  ScheduledWorkflowJob jobFromJson(Map<String, dynamic> json) {
    return ScheduledWorkflowJob(
      id: json['id'] as String? ?? '',
      definitionId: json['definitionId'] as String? ?? '',
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '') ?? DateTime.now(),
      payload: (json['payload'] as Map?)?.cast<String, Object?>() ?? const <String, Object?>{},
      enabled: json['enabled'] as bool? ?? true,
      lastRunAt: DateTime.tryParse(json['lastRunAt'] as String? ?? ''),
    );
  }

  Map<String, Object?> definitionToJson(WorkflowDefinition definition) {
    return <String, Object?>{
      'id': definition.id,
      'name': definition.name,
      'description': definition.description,
      'module': definition.module,
      'enabled': definition.enabled,
      'rules': definition.rules.map(_ruleToJson).toList(growable: false),
      'triggers': definition.triggers.map(_triggerToJson).toList(growable: false),
      'transitions': definition.transitions.map(_transitionToJson).toList(growable: false),
      if (definition.escalationPolicy != null)
        'escalationPolicy': _escalationToJson(definition.escalationPolicy!),
    };
  }

  Map<String, Object?> jobToJson(ScheduledWorkflowJob job) {
    return <String, Object?>{
      'id': job.id,
      'definitionId': job.definitionId,
      'scheduledAt': job.scheduledAt.toIso8601String(),
      'payload': job.payload,
      'enabled': job.enabled,
      if (job.lastRunAt != null) 'lastRunAt': job.lastRunAt!.toIso8601String(),
    };
  }

  WorkflowRule _ruleFromJson(Map<String, dynamic> json) {
    return WorkflowRule(
      id: json['id'] as String? ?? '',
      field: json['field'] as String? ?? '',
      operator: WorkflowRuleOperator.values.firstWhere(
        (value) => value.name == (json['operator'] as String? ?? ''),
        orElse: () => WorkflowRuleOperator.equals,
      ),
      value: json['value'],
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  WorkflowTrigger _triggerFromJson(Map<String, dynamic> json) {
    return WorkflowTrigger(
      id: json['id'] as String? ?? '',
      type: WorkflowTriggerType.values.firstWhere(
        (value) => value.name == (json['type'] as String? ?? ''),
        orElse: () => WorkflowTriggerType.approvalRequested,
      ),
      required: json['required'] as bool? ?? true,
      metadata: (json['metadata'] as Map?)?.cast<String, Object?>() ?? const <String, Object?>{},
    );
  }

  WorkflowTransition _transitionFromJson(Map<String, dynamic> json) {
    return WorkflowTransition(
      id: json['id'] as String? ?? '',
      fromStatus: _status(json['fromStatus'] as String? ?? 'queued'),
      toStatus: _status(json['toStatus'] as String? ?? 'active'),
      action: json['action'] as String? ?? '',
      autoApprove: json['autoApprove'] as bool? ?? false,
      autoRouteToRole: json['autoRouteToRole'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, Object?>() ?? const <String, Object?>{},
    );
  }

  EscalationPolicy _escalationFromJson(Map<String, dynamic> json) {
    return EscalationPolicy(
      duration: Duration(minutes: (json['durationMinutes'] as num?)?.toInt() ?? 0),
      escalateToRole: json['escalateToRole'] as String? ?? 'principal',
      maxEscalationLevel: (json['maxEscalationLevel'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> _ruleToJson(WorkflowRule rule) {
    return <String, Object?>{
      'id': rule.id,
      'field': rule.field,
      'operator': rule.operator.name,
      'value': rule.value,
      'enabled': rule.enabled,
    };
  }

  Map<String, Object?> _triggerToJson(WorkflowTrigger trigger) {
    return <String, Object?>{
      'id': trigger.id,
      'type': trigger.type.name,
      'required': trigger.required,
      'metadata': trigger.metadata,
    };
  }

  Map<String, Object?> _transitionToJson(WorkflowTransition transition) {
    return <String, Object?>{
      'id': transition.id,
      'fromStatus': transition.fromStatus.name,
      'toStatus': transition.toStatus.name,
      'action': transition.action,
      'autoApprove': transition.autoApprove,
      if (transition.autoRouteToRole != null) 'autoRouteToRole': transition.autoRouteToRole,
      'metadata': transition.metadata,
    };
  }

  Map<String, Object?> _escalationToJson(EscalationPolicy policy) {
    return <String, Object?>{
      'durationMinutes': policy.duration.inMinutes,
      'escalateToRole': policy.escalateToRole,
      'maxEscalationLevel': policy.maxEscalationLevel,
    };
  }

  WorkflowInstanceStatus _status(String value) {
    return WorkflowInstanceStatus.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => WorkflowInstanceStatus.queued,
    );
  }

  List<Map<String, dynamic>> _list(Object? value) {
    final items = value as List<dynamic>? ?? const <dynamic>[];
    return items.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList(growable: false);
  }
}
