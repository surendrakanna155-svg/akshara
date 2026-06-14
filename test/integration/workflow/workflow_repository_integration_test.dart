import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/workflow/workflow_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  group('Workflow repository integration', () {
    test('mock repository trigger lifecycle through provider', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      final repository = container.read(workflowRepositoryProvider);
      final instance = await repository.triggerWorkflow(
        query: RepositoryQuery.demo,
        triggerType: WorkflowTriggerType.feeOverdue,
        payload: const <String, Object?>{
          'overdueDays': 22,
          'amount': 12000,
        },
      );
      expect(instance, isNotNull);

      final list = await repository.listInstances(
        query: RepositoryQuery.demo,
      );
      expect(list, isNotEmpty);
    });
  });
}
