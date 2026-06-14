import 'package:akshara_erp/core/repositories/interfaces/workflow_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_workflow_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/workflow/workflow_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery.demo;

void main() {
  group('Workflow repository contract', () {
    late MockWorkflowRepository repository;

    setUp(() {
      repository = MockWorkflowRepository();
    });

    test('implements interface', () {
      expect(repository, isA<WorkflowRepository>());
    });

    test('trigger + execute action workflow instance', () async {
      final instance = await repository.triggerWorkflow(
        query: _query,
        triggerType: WorkflowTriggerType.atRiskTierChanged,
        payload: const <String, Object?>{
          'toTier': 'high',
          'studentId': 'SIS-101',
        },
      );
      expect(instance, isNotNull);

      final updated = await repository.executeAction(
        query: _query,
        instanceId: instance!.id,
        transitionAction: 'route_intervention_team',
      );
      expect(updated.status, anyOf(WorkflowInstanceStatus.routed, WorkflowInstanceStatus.approved));
    });
  });
}
