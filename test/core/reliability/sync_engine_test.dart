import 'package:akshara_erp/core/reliability/model/mutation_envelope.dart';
import 'package:akshara_erp/core/reliability/model/operation_policy.dart';
import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/reliability/sync/backoff.dart';
import 'package:akshara_erp/core/reliability/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reliability_fakes.dart';

void main() {
  late InMemoryReliabilityStore store;
  late FakeConnectivity conn;
  late FixedClock clock;
  final DateTime t0 = DateTime.utc(2026, 6, 27, 9);

  setUp(() {
    store = InMemoryReliabilityStore();
    conn = FakeConnectivity();
    clock = FixedClock(t0);
  });

  OperationPolicyRegistry registryWith(Map<String, OperationPolicy> p) =>
      OperationPolicyRegistry(p);

  Future<void> enqueuePending(String type, {String id = 'op1'}) async {
    await store.putOperation(
      MutationEnvelope(
        request: req(type, id: id),
        status: SyncStatus.pending,
        createdAt: t0,
      ),
    );
  }

  test('confirms a queued write on 200 (single send)', () async {
    final FakeExecutor exec = FakeExecutor((_, __) => ok());
    final engine = SyncEngine(
      store: store,
      executor: exec,
      connectivity: conn,
      registry: registryWith(const {}),
      clock: clock,
    );
    await enqueuePending('attendance.mark');

    await engine.flush();

    expect(exec.callCount, 1);
    expect((await store.getOperation('op1'))!.status, SyncStatus.confirmed);
    expect(await store.pendingOperations(), isEmpty);
  });

  test('idempotency replay (409 IDEMPOTENCY_CONFLICT) is treated as confirmed '
      '— exactly-once even when the original ack was lost', () async {
    final FakeExecutor exec = FakeExecutor((_, __) => idempotencyReplay());
    final engine = SyncEngine(
      store: store,
      executor: exec,
      connectivity: conn,
      registry: registryWith(const {}),
      clock: clock,
    );
    await enqueuePending('attendance.mark');

    await engine.flush();

    expect((await store.getOperation('op1'))!.status, SyncStatus.confirmed);
  });

  test('transient 5xx retries with backoff, then confirms after delay elapses',
      () async {
    int calls = 0;
    final FakeExecutor exec = FakeExecutor((_, i) {
      calls++;
      return i == 0 ? serverError() : ok();
    });
    final engine = SyncEngine(
      store: store,
      executor: exec,
      connectivity: conn,
      registry: registryWith(const {}),
      backoff: const Backoff(base: Duration(seconds: 2)),
      clock: clock,
      random: FixedRandom(1.0), // full delay, deterministic
    );
    await enqueuePending('attendance.mark');

    await engine.flush(); // 503 → pending, attempt 1, nextAttemptAt = +2s
    final op1 = (await store.getOperation('op1'))!;
    expect(op1.status, SyncStatus.pending);
    expect(op1.attempts, 1);
    expect(op1.nextAttemptAt, isNotNull);

    await engine.flush(); // backoff not elapsed → skipped
    expect(calls, 1);

    clock.advance(const Duration(seconds: 2));
    await engine.flush(); // now due → 200 → confirmed
    expect((await store.getOperation('op1'))!.status, SyncStatus.confirmed);
    expect(calls, 2);
  });

  test('high-risk conflict is PARKED for explicit resolution (never overwrites)',
      () async {
    final FakeExecutor exec =
        FakeExecutor((_, __) => conflict(<String, dynamic>{'row_version': 7}));
    final engine = SyncEngine(
      store: store,
      executor: exec,
      connectivity: conn,
      registry: registryWith(const {
        'finance.collectFee': OperationPolicy(
          kind: OperationKind.queueable,
          conflictCategory: ConflictCategory.highRisk,
        ),
      }),
      clock: clock,
    );
    await enqueuePending('finance.collectFee');

    await engine.flush();
    final op = (await store.getOperation('op1'))!;
    expect(op.status, SyncStatus.conflict);
    expect(op.serverRow, <String, dynamic>{'row_version': 7});

    await engine.flush(); // parked conflicts are not retried automatically
    expect(exec.callCount, 1);
  });

  test('low-risk conflict re-applies (LWW) carrying server version precondition',
      () async {
    final FakeExecutor exec = FakeExecutor((r, i) {
      if (i == 0) return conflict(<String, dynamic>{'row_version': 9});
      return ok();
    });
    final engine = SyncEngine(
      store: store,
      executor: exec,
      connectivity: conn,
      registry: registryWith(const {
        'attendance.mark': OperationPolicy(
          kind: OperationKind.queueable,
          conflictCategory: ConflictCategory.lowRisk,
        ),
      }),
      backoff: const Backoff(base: Duration(seconds: 1)),
      clock: clock,
      random: FixedRandom(1.0),
    );
    await enqueuePending('attendance.mark');

    await engine.flush(); // 409 → re-enqueued pending with expectedVersion
    final op = (await store.getOperation('op1'))!;
    expect(op.status, SyncStatus.pending);
    expect(op.attempts, 1);

    clock.advance(const Duration(seconds: 1));
    await engine.flush(); // re-sent with precondition → 200 confirmed
    expect((await store.getOperation('op1'))!.status, SyncStatus.confirmed);
    expect(exec.sent[1].body['expectedVersion'], 9);
  });

  test('permanent 4xx fails immediately (no retry)', () async {
    final FakeExecutor exec = FakeExecutor((_, __) => validationError());
    final engine = SyncEngine(
      store: store,
      executor: exec,
      connectivity: conn,
      registry: registryWith(const {}),
      clock: clock,
    );
    await enqueuePending('attendance.mark');

    await engine.flush();
    final op = (await store.getOperation('op1'))!;
    expect(op.status, SyncStatus.failed);
    expect(op.lastError, 'VALIDATION_ERROR');
  });

  test('retry exhaustion parks the op as failed', () async {
    final FakeExecutor exec = FakeExecutor((_, __) => serverError());
    final engine = SyncEngine(
      store: store,
      executor: exec,
      connectivity: conn,
      registry: registryWith(const {}),
      backoff: const Backoff(base: Duration(milliseconds: 1)),
      clock: clock,
      random: FixedRandom(0.0), // zero delay → always due
    );
    await enqueuePending('attendance.mark');

    // 10 attempts allowed; drive past the cap.
    for (int i = 0; i < 12; i++) {
      await engine.flush();
    }
    expect((await store.getOperation('op1'))!.status, SyncStatus.failed);
  });

  test('resolveConflict keepClient re-queues; otherwise drops', () async {
    final FakeExecutor exec =
        FakeExecutor((_, __) => conflict(<String, dynamic>{'row_version': 3}));
    final engine = SyncEngine(
      store: store,
      executor: exec,
      connectivity: conn,
      registry: registryWith(const {
        'finance.collectFee': OperationPolicy(
          kind: OperationKind.queueable,
          conflictCategory: ConflictCategory.highRisk,
        ),
      }),
      clock: clock,
    );
    await enqueuePending('finance.collectFee', id: 'opA');
    await engine.flush();
    expect((await store.getOperation('opA'))!.status, SyncStatus.conflict);

    await engine.resolveConflict('opA', keepClient: true);
    expect((await store.getOperation('opA'))!.status, SyncStatus.pending);

    await store.putOperation((await store.getOperation('opA'))!
        .copyWith(status: SyncStatus.conflict));
    await engine.resolveConflict('opA', keepClient: false);
    expect(await store.getOperation('opA'), isNull);
  });
}
