import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:akshara_erp/core/reliability/reliable_writer.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/reliability/store/reliability_store.dart';
import 'package:akshara_erp/core/reliability/sync/mutation_gateway.dart';
import 'package:akshara_erp/core/repositories/api/finance/mapper/finance_mapper.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/finance/finance_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/reliability/reliability_fakes.dart';

/// Refinement R1 (airplane-mode): an offline fee collection is queued and shown
/// as "Pending Sync" — and crucially NO final receipt is minted until the
/// server confirms. Online, it returns a confirmed receipt as before.
void main() {
  const RepositoryQuery query =
      RepositoryQuery(tenantId: 'tenant-1', schoolId: 'school-1');
  const FinanceMapper mapper = FinanceMapper();

  CreateCollectionRequest request() => const CreateCollectionRequest(
        invoiceId: 'inv-1',
        amountCollected: '5000',
        paymentMethod: 'Cash',
        collectionDate: 'Today',
      );

  FinanceRemoteDataSource datasourceFor({
    required bool online,
    required FakeExecutor executor,
    required ReliabilityStore store,
  }) {
    final gateway = MutationGateway(
      registry: OperationPolicyRegistry.withDefaults(),
      executor: executor,
      store: store,
      connectivity: FakeConnectivity(online: online),
    );
    return FinanceRemoteDataSource(Dio(), reliableWriter: ReliableWriter(gateway));
  }

  test('offline collection → Pending Sync, NO final receipt (R1)', () async {
    final store = InMemoryReliabilityStore();
    final executor = FakeExecutor((req, _) => ok());
    final ds = datasourceFor(online: false, executor: executor, store: store);

    final dto = await ds.createCollection(query: query, request: request());
    final result = mapper.toCollectionResult(dto);

    expect(result.pendingSync, isTrue, reason: 'queued, not server-confirmed');
    expect(result.receiptNumber, isEmpty,
        reason: 'a final receipt must not be minted offline (R1)');
    expect(executor.callCount, 0, reason: 'nothing sent while offline');
    expect(await store.pendingOperations(), hasLength(1));
  });

  test('online collection → confirmed with a real receipt', () async {
    final store = InMemoryReliabilityStore();
    final executor = FakeExecutor(
      (req, _) => ok(<String, dynamic>{
        'collection': <String, dynamic>{
          'id': 'col-1',
          'invoiceId': 'inv-1',
          'receiptNumber': 'RCPT-001',
          'amountCollected': '5000',
        },
        'receipt': <String, dynamic>{'receiptNumber': 'RCPT-001'},
        'invoice': <String, dynamic>{},
      }),
    );
    final ds = datasourceFor(online: true, executor: executor, store: store);

    final dto = await ds.createCollection(query: query, request: request());
    final result = mapper.toCollectionResult(dto);

    expect(result.pendingSync, isFalse);
    expect(result.receiptNumber, 'RCPT-001');
    expect(executor.callCount, 1);
  });
}
