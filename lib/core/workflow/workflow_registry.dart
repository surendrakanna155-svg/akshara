import 'workflow_models.dart';

class WorkflowRegistry {
  const WorkflowRegistry._();

  static List<WorkflowDefinition> seedSchoolPackDefinitions() {
    return <WorkflowDefinition>[
      const WorkflowDefinition(
        id: 'wf-attendance-absent',
        name: 'Attendance absent escalation',
        description: 'Creates escalation when student absence threshold is crossed.',
        module: 'student-success',
        enabled: true,
        rules: <WorkflowRule>[
          WorkflowRule(
            id: 'attendance-below-threshold',
            field: 'attendancePercent',
            operator: WorkflowRuleOperator.lessThan,
            value: 75,
          ),
        ],
        triggers: <WorkflowTrigger>[
          WorkflowTrigger(id: 'attendance-absent', type: WorkflowTriggerType.attendanceAbsent),
        ],
        transitions: <WorkflowTransition>[
          WorkflowTransition(
            id: 'auto-route-counselor',
            fromStatus: WorkflowInstanceStatus.queued,
            toStatus: WorkflowInstanceStatus.routed,
            action: 'route_to_counselor',
            autoRouteToRole: 'counselor',
          ),
        ],
        escalationPolicy: EscalationPolicy(
          duration: Duration(hours: 24),
          escalateToRole: 'principal',
          maxEscalationLevel: 2,
        ),
      ),
      const WorkflowDefinition(
        id: 'wf-fee-overdue',
        name: 'Fee overdue approvals',
        description: 'Auto-routes overdue fee cases for finance review.',
        module: 'finance',
        enabled: true,
        rules: <WorkflowRule>[
          WorkflowRule(
            id: 'fee-overdue-days',
            field: 'overdueDays',
            operator: WorkflowRuleOperator.greaterThan,
            value: 15,
          ),
        ],
        triggers: <WorkflowTrigger>[
          WorkflowTrigger(id: 'fee-overdue-trigger', type: WorkflowTriggerType.feeOverdue),
        ],
        transitions: <WorkflowTransition>[
          WorkflowTransition(
            id: 'auto-approve-small-dues',
            fromStatus: WorkflowInstanceStatus.queued,
            toStatus: WorkflowInstanceStatus.approved,
            action: 'auto_approve_small_overdue',
            autoApprove: true,
          ),
          WorkflowTransition(
            id: 'route-finance-manager',
            fromStatus: WorkflowInstanceStatus.approved,
            toStatus: WorkflowInstanceStatus.routed,
            action: 'route_finance_manager',
            autoRouteToRole: 'finance_manager',
          ),
        ],
      ),
      const WorkflowDefinition(
        id: 'wf-at-risk-student',
        name: 'At-risk student intervention',
        description: 'Enqueues intervention workflow for high/critical tier changes.',
        module: 'intelligence',
        enabled: true,
        rules: <WorkflowRule>[
          WorkflowRule(
            id: 'at-risk-tier-high',
            field: 'toTier',
            operator: WorkflowRuleOperator.contains,
            value: 'high',
          ),
        ],
        triggers: <WorkflowTrigger>[
          WorkflowTrigger(
            id: 'risk-tier-change',
            type: WorkflowTriggerType.atRiskTierChanged,
          ),
        ],
        transitions: <WorkflowTransition>[
          WorkflowTransition(
            id: 'route-intervention-team',
            fromStatus: WorkflowInstanceStatus.queued,
            toStatus: WorkflowInstanceStatus.routed,
            action: 'route_intervention_team',
            autoRouteToRole: 'student_success_team',
          ),
        ],
        escalationPolicy: EscalationPolicy(
          duration: Duration(hours: 12),
          escalateToRole: 'principal',
          maxEscalationLevel: 1,
        ),
      ),
      const WorkflowDefinition(
        id: 'wf-approval-routing',
        name: 'Management approval routing',
        description: 'Routes approvals based on amount and urgency.',
        module: 'management',
        enabled: true,
        rules: <WorkflowRule>[
          WorkflowRule(
            id: 'approval-amount',
            field: 'amount',
            operator: WorkflowRuleOperator.greaterThan,
            value: 10000,
          ),
        ],
        triggers: <WorkflowTrigger>[
          WorkflowTrigger(
            id: 'approval-requested',
            type: WorkflowTriggerType.approvalRequested,
          ),
        ],
        transitions: <WorkflowTransition>[
          WorkflowTransition(
            id: 'route-school-admin',
            fromStatus: WorkflowInstanceStatus.queued,
            toStatus: WorkflowInstanceStatus.routed,
            action: 'route_school_admin',
            autoRouteToRole: 'school_admin',
          ),
        ],
      ),
    ];
  }
}
