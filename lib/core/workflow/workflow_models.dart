import 'package:flutter/foundation.dart';

enum WorkflowRuleOperator {
  equals,
  notEquals,
  greaterThan,
  lessThan,
  contains,
}

enum WorkflowTriggerType {
  attendanceAbsent,
  feeOverdue,
  atRiskTierChanged,
  approvalRequested,
  scheduled,
}

enum WorkflowInstanceStatus { queued, active, approved, routed, completed, escalated, failed }

@immutable
class WorkflowRule {
  const WorkflowRule({
    required this.id,
    required this.field,
    required this.operator,
    required this.value,
    this.enabled = true,
  });

  final String id;
  final String field;
  final WorkflowRuleOperator operator;
  final Object? value;
  final bool enabled;
}

@immutable
class WorkflowTrigger {
  const WorkflowTrigger({
    required this.id,
    required this.type,
    this.required = true,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final WorkflowTriggerType type;
  final bool required;
  final Map<String, Object?> metadata;
}

@immutable
class EscalationPolicy {
  const EscalationPolicy({
    required this.duration,
    required this.escalateToRole,
    this.maxEscalationLevel = 1,
  });

  final Duration duration;
  final String escalateToRole;
  final int maxEscalationLevel;
}

@immutable
class WorkflowTransition {
  const WorkflowTransition({
    required this.id,
    required this.fromStatus,
    required this.toStatus,
    required this.action,
    this.autoApprove = false,
    this.autoRouteToRole,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final WorkflowInstanceStatus fromStatus;
  final WorkflowInstanceStatus toStatus;
  final String action;
  final bool autoApprove;
  final String? autoRouteToRole;
  final Map<String, Object?> metadata;
}

@immutable
class WorkflowDefinition {
  const WorkflowDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.module,
    required this.enabled,
    required this.rules,
    required this.triggers,
    required this.transitions,
    this.escalationPolicy,
  });

  final String id;
  final String name;
  final String description;
  final String module;
  final bool enabled;
  final List<WorkflowRule> rules;
  final List<WorkflowTrigger> triggers;
  final List<WorkflowTransition> transitions;
  final EscalationPolicy? escalationPolicy;
}

@immutable
class WorkflowInstance {
  const WorkflowInstance({
    required this.id,
    required this.definitionId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.currentAssigneeRole,
    required this.payload,
    this.escalationLevel = 0,
    this.lastEscalatedAt,
    this.auditTrail = const <String>[],
  });

  final String id;
  final String definitionId;
  final WorkflowInstanceStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String currentAssigneeRole;
  final Map<String, Object?> payload;
  final int escalationLevel;
  final DateTime? lastEscalatedAt;
  final List<String> auditTrail;

  WorkflowInstance copyWith({
    WorkflowInstanceStatus? status,
    DateTime? updatedAt,
    String? currentAssigneeRole,
    int? escalationLevel,
    DateTime? lastEscalatedAt,
    List<String>? auditTrail,
    Map<String, Object?>? payload,
  }) {
    return WorkflowInstance(
      id: id,
      definitionId: definitionId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentAssigneeRole: currentAssigneeRole ?? this.currentAssigneeRole,
      payload: payload ?? this.payload,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      lastEscalatedAt: lastEscalatedAt ?? this.lastEscalatedAt,
      auditTrail: auditTrail ?? this.auditTrail,
    );
  }
}

@immutable
class ScheduledWorkflowJob {
  const ScheduledWorkflowJob({
    required this.id,
    required this.definitionId,
    required this.scheduledAt,
    required this.payload,
    this.enabled = true,
    this.lastRunAt,
  });

  final String id;
  final String definitionId;
  final DateTime scheduledAt;
  final Map<String, Object?> payload;
  final bool enabled;
  final DateTime? lastRunAt;

  ScheduledWorkflowJob copyWith({DateTime? lastRunAt, bool? enabled}) {
    return ScheduledWorkflowJob(
      id: id,
      definitionId: definitionId,
      scheduledAt: scheduledAt,
      payload: payload,
      enabled: enabled ?? this.enabled,
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }
}
