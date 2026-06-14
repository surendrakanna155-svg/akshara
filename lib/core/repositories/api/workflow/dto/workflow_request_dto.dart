import '../../../../workflow/workflow_models.dart';

class WorkflowTriggerRequestDto {
  const WorkflowTriggerRequestDto({
    required this.triggerType,
    required this.payload,
  });

  final WorkflowTriggerType triggerType;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'triggerType': triggerType.name,
      'payload': payload,
    };
  }
}

class WorkflowActionRequestDto {
  const WorkflowActionRequestDto({
    required this.transitionAction,
    this.actorRole,
  });

  final String transitionAction;
  final String? actorRole;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'transitionAction': transitionAction,
      if (actorRole != null) 'actorRole': actorRole,
    };
  }
}
