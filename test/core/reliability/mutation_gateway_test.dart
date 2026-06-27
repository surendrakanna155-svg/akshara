import 'package:akshara_erp/core/reliability/model/operation_policy.dart';
import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/reliability/sync/mutation_executor.dart';
import 'package:akshara_erp/core/reliability/sync/mutation_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reliability_fakes.dart';

void main() {
  late InMemoryReliabilityStore store;
  late FixedClock clock;
  final DateTime t0 = DateTime.utc(2026, 6, 27, 9);

  setUp(() {
    store = InMemoryReliabilityStore();
    clock = FixedClock(t0);
  });

  MutationGateway gateway(
    FakeExecutor exec,
    FakeConnectivity conn, {
    Map<String, OperationPolicy> policies = const {},
  }) {
    return MutationGateway(
      registry: OperationPolicyRegistry(policies),
      executor: exec,
      store: store,
      connectivity: conn,
      clock: clock,
    );
  }

  test('online-only success returns confirmed and does NOT queue', () async {
    final exec = FakeExecutor((_, __) => ok(<String, dynamic>{'id': 'x'}));
    final g = gateway(exec, FakeConnectivity(online: true), policies: const {
      'auth.login': OperationPolicy(kind: OperationKind.onlineOnly),
    });

    final outcome = await g.execute(req('auth.login'));
    expect(outcome.status, SyncStatus.confirmed);
    expect(outcome.isFinal, isTrue);
    expect(await store.allOperations(), isEmpty);
  });

  test('online-only while offline fails fast (never queued)', () async {
    final exec = FakeExecutor((_, __) => throw const NetworkUnavailableException());
    final g = gateway(exec, FakeConnectivity(online: false), policies: const {
      'auth.login': OperationPolicy(kind: OperationKind.onlineOnly),
    });

    final outcome = await g.execute(req('auth.login'));
    expect(outcome.status, SyncStatus.failed);
    expect(outcome.errorCode, 'OFFLINE');
    expect(await store.allOperations(), isEmpty);
  });

  test('queueable while offline returns pending (non-final) and enqueues',
      () async {
    final exec = FakeExecutor((_, __) => ok());
    final g = gateway(exec, FakeConnectivity(online: false), policies: const {
      'attendance.mark': OperationPolicy(
        kind: OperationKind.queueable,
        conflictCategory: ConflictCategory.lowRisk,
      ),
    });

    final outcome = await g.execute(req('attendance.mark', id: 'opQ'));
    expect(outcome.status, SyncStatus.pending);
    expect(outcome.isFinal, isFalse); // R1: not a final/server-backed fact
    expect(exec.callCount, 0); // offline: never sent
    final pending = await store.pendingOperations();
    expect(pending.single.id, 'opQ');
  });

  test('queueable online success confirms immediately', () async {
    final exec = FakeExecutor((_, __) => ok(<String, dynamic>{'receipt': 'R1'}));
    final g = gateway(exec, FakeConnectivity(online: true), policies: const {
      'finance.collectFee': OperationPolicy(
        kind: OperationKind.queueable,
        conflictCategory: ConflictCategory.highRisk,
      ),
    });

    final outcome = await g.execute(req('finance.collectFee'));
    expect(outcome.status, SyncStatus.confirmed);
    expect(outcome.data, <String, dynamic>{'receipt': 'R1'});
  });

  test('queueable online 5xx enqueues for retry (pending)', () async {
    final exec = FakeExecutor((_, __) => serverError());
    final g = gateway(exec, FakeConnectivity(online: true), policies: const {
      'attendance.mark': OperationPolicy(kind: OperationKind.queueable),
    });

    final outcome = await g.execute(req('attendance.mark', id: 'opR'));
    expect(outcome.status, SyncStatus.pending);
    expect((await store.pendingOperations()).single.id, 'opR');
  });

  test('queueable online high-risk 409 returns conflict with server row',
      () async {
    final exec =
        FakeExecutor((_, __) => conflict(<String, dynamic>{'row_version': 4}));
    final g = gateway(exec, FakeConnectivity(online: true), policies: const {
      'finance.collectFee': OperationPolicy(
        kind: OperationKind.queueable,
        conflictCategory: ConflictCategory.highRisk,
      ),
    });

    final outcome = await g.execute(req('finance.collectFee'));
    expect(outcome.status, SyncStatus.conflict);
    expect(outcome.serverRow, <String, dynamic>{'row_version': 4});
  });

  test('queueable online permanent 4xx fails (not queued for retry)', () async {
    final exec = FakeExecutor((_, __) => validationError());
    final g = gateway(exec, FakeConnectivity(online: true), policies: const {
      'attendance.mark': OperationPolicy(kind: OperationKind.queueable),
    });

    final outcome = await g.execute(req('attendance.mark', id: 'opF'));
    expect(outcome.status, SyncStatus.failed);
    expect((await store.pendingOperations()), isEmpty);
  });

  test('unregistered operation falls back to online-only (no behaviour change)',
      () async {
    final exec = FakeExecutor((_, __) => ok());
    final g = gateway(exec, FakeConnectivity(online: true));

    final outcome = await g.execute(req('some.new.thing'));
    expect(outcome.status, SyncStatus.confirmed);
    expect(await store.allOperations(), isEmpty); // not queued
  });
}
