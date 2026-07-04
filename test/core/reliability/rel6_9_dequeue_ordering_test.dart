import 'package:akshara_erp/core/reliability/model/mutation_envelope.dart';
import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/reliability/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reliability_fakes.dart';

/// P1-CODE-2 — REL-6 (crash-safe dequeue) + REL-9 (per-entity ordering).
void main() {
  late InMemoryReliabilityStore store;
  late FakeConnectivity conn;
  late FixedClock clock;
  final DateTime t0 = DateTime.utc(2026, 7, 4, 9);

  setUp(() {
    store = InMemoryReliabilityStore();
    conn = FakeConnectivity();
    clock = FixedClock(t0);
  });

  SyncEngine engineWith(FakeExecutor exec) => SyncEngine(
        store: store,
        executor: exec,
        connectivity: conn,
        registry: OperationPolicyRegistry.withDefaults(),
        clock: clock,
      );

  Future<void> put(
    String id, {
    required SyncStatus status,
    String type = 'attendance.mark',
    String? entityRef,
    DateTime? createdAt,
  }) async {
    await store.putOperation(
      MutationEnvelope(
        request: req(type, id: id, entityRef: entityRef),
        status: status,
        createdAt: createdAt ?? t0,
      ),
    );
  }

  group('REL-6 — crash-safe dequeue (reclaim orphaned in-flight)', () {
    test('reclaimInFlightOperations flips in_flight → pending', () async {
      await put('a', status: SyncStatus.inFlight);
      await put('b', status: SyncStatus.pending);
      await put('c', status: SyncStatus.confirmed);

      final count = await store.reclaimInFlightOperations();

      expect(count, 1);
      expect((await store.getOperation('a'))!.status, SyncStatus.pending);
      expect((await store.getOperation('b'))!.status, SyncStatus.pending);
      expect((await store.getOperation('c'))!.status, SyncStatus.confirmed);
    });

    test('flush re-drains an op a prior run stranded in_flight — not dropped',
        () async {
      // Simulate a crash mid-send: the op is durably in_flight, never confirmed.
      await put('orphan', status: SyncStatus.inFlight);
      final exec = FakeExecutor((_, __) => ok());

      await engineWith(exec).flush();

      // The idempotency key makes the re-send safe; the op now confirms.
      expect(exec.callCount, 1);
      expect((await store.getOperation('orphan'))!.status, SyncStatus.confirmed);
    });

    test('without reclaim an in_flight orphan is invisible to pendingOperations',
        () async {
      await put('orphan', status: SyncStatus.inFlight);
      expect(await store.pendingOperations(), isEmpty); // the bug REL-6 fixes
    });
  });

  group('REL-9 — per-entity ordering', () {
    test('a newer write for an entity is HELD when the older one does not '
        'confirm this drain', () async {
      // Two writes for the SAME entity; the first (older) hits a transient
      // failure, the second (newer) must not be attempted this drain.
      await put('e1-old',
          status: SyncStatus.pending,
          entityRef: 'exam:1',
          createdAt: t0);
      await put('e1-new',
          status: SyncStatus.pending,
          entityRef: 'exam:1',
          createdAt: t0.add(const Duration(seconds: 1)));

      final exec = FakeExecutor((r, __) =>
          r.idempotencyKey == 'e1-old' ? serverError() : ok());

      await engineWith(exec).flush();

      // Only the older op was attempted; the newer one stayed pending, in order.
      expect(exec.sent.map((r) => r.idempotencyKey), <String>['e1-old']);
      expect((await store.getOperation('e1-new'))!.status, SyncStatus.pending);
    });

    test('writes for DIFFERENT entities are not blocked by each other',
        () async {
      await put('a', status: SyncStatus.pending, entityRef: 'exam:1');
      await put('b', status: SyncStatus.pending, entityRef: 'exam:2');

      final exec = FakeExecutor(
          (r, __) => r.idempotencyKey == 'a' ? serverError() : ok());

      await engineWith(exec).flush();

      // 'a' failed but must not hold 'b' (a different entity) — both attempted.
      expect(exec.callCount, 2);
      expect((await store.getOperation('b'))!.status, SyncStatus.confirmed);
    });

    test('an unreachable network (captive portal: online but no internet) '
        'skips the drain — writes stay pending', () async {
      conn.setReachable(false); // isOnline stays true, isReachable false
      await put('a', status: SyncStatus.pending, entityRef: 'exam:1');
      final exec = FakeExecutor((_, __) => ok());

      await engineWith(exec).flush();

      expect(exec.callCount, 0, reason: 'no send attempted while unreachable');
      expect((await store.getOperation('a'))!.status, SyncStatus.pending);

      // Once genuinely reachable, the same op drains normally.
      conn.setReachable(true);
      await engineWith(exec).flush();
      expect(exec.callCount, 1);
      expect((await store.getOperation('a'))!.status, SyncStatus.confirmed);
    });

    test('same-entity writes both apply in order when the first confirms',
        () async {
      await put('e1-old',
          status: SyncStatus.pending, entityRef: 'exam:1', createdAt: t0);
      await put('e1-new',
          status: SyncStatus.pending,
          entityRef: 'exam:1',
          createdAt: t0.add(const Duration(seconds: 1)));

      final exec = FakeExecutor((_, __) => ok());

      await engineWith(exec).flush();

      expect(exec.sent.map((r) => r.idempotencyKey),
          <String>['e1-old', 'e1-new']);
      expect((await store.getOperation('e1-new'))!.status, SyncStatus.confirmed);
    });
  });
}
