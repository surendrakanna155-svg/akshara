import 'package:akshara_erp/core/workflow/workflow_engine.dart';
import 'package:akshara_erp/core/workflow/workflow_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkflowEngine', () {
    const definition = WorkflowDefinition(
      id: 'wf-1',
      name: 'At-risk workflow',
      description: 'Test definition',
      module: 'intelligence',
      enabled: true,
      rules: <WorkflowRule>[
        WorkflowRule(
          id: 'risk-rule',
          field: 'toTier',
          operator: WorkflowRuleOperator.contains,
          value: 'high',
        ),
      ],
      triggers: <WorkflowTrigger>[
        WorkflowTrigger(id: 'trigger', type: WorkflowTriggerType.atRiskTierChanged),
      ],
      transitions: <WorkflowTransition>[
        WorkflowTransition(
          id: 'route',
          fromStatus: WorkflowInstanceStatus.queued,
          toStatus: WorkflowInstanceStatus.routed,
          action: 'route_school_admin',
          autoRouteToRole: 'school_admin',
        ),
      ],
      escalationPolicy: EscalationPolicy(
        duration: Duration(hours: 6),
        escalateToRole: 'principal',
      ),
    );

    test('evaluateRules validates rule set', () {
      const engine = WorkflowEngine();
      final pass = engine.evaluateRules(
        definition,
        <String, Object?>{'toTier': 'high'},
      );
      final fail = engine.evaluateRules(
        definition,
        <String, Object?>{'toTier': 'low'},
      );
      expect(pass, isTrue);
      expect(fail, isFalse);
    });

    test('executeTrigger creates workflow instance', () {
      const engine = WorkflowEngine();
      final instance = engine.executeTrigger(
        definition: definition,
        triggerType: WorkflowTriggerType.atRiskTierChanged,
        payload: <String, Object?>{'toTier': 'high'},
      );
      expect(instance, isNotNull);
      expect(instance!.status, WorkflowInstanceStatus.queued);
    });

    test('applyTransition auto-routes role', () {
      const engine = WorkflowEngine();
      final instance = engine.executeTrigger(
        definition: definition,
        triggerType: WorkflowTriggerType.atRiskTierChanged,
        payload: <String, Object?>{'toTier': 'high'},
      )!;
      final updated = engine.applyTransition(
        instance: instance,
        transition: definition.transitions.first,
      );
      expect(updated.status, WorkflowInstanceStatus.routed);
      expect(updated.currentAssigneeRole, 'school_admin');
    });

    test('escalate increments level', () {
      const engine = WorkflowEngine();
      final instance = engine.executeTrigger(
        definition: definition,
        triggerType: WorkflowTriggerType.atRiskTierChanged,
        payload: <String, Object?>{'toTier': 'high'},
      )!;
      final escalated = engine.escalate(
        instance: instance,
        policy: definition.escalationPolicy!,
      );
      expect(escalated.status, WorkflowInstanceStatus.escalated);
      expect(escalated.escalationLevel, 1);
      expect(escalated.currentAssigneeRole, 'principal');
    });
  });
}
