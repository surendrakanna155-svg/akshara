import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/reliability/store/reliability_store_opener.dart';
import 'package:akshara_erp/core/reliability/sync/sync_engine.dart';
import 'package:akshara_erp/core/reliability/sync_center/sync_center_controller.dart';
import 'package:akshara_erp/core/reliability/sync_center/sync_summary.dart';
import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reliability_fakes.dart';

/// P1-CODE-2 · REL-8 — a non-durable store fallback (encrypted DB open failed)
/// must be OBSERVABLE, not silent: it flows through the open result → the Sync
/// Center summary → the banner, so the app can warn work isn't being saved.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncSummary durability flag', () {
    test('durabilityDegraded forces the banner even when online + idle', () {
      const healthy = SyncSummary(online: true);
      const degraded = SyncSummary(online: true, durabilityDegraded: true);
      expect(healthy.shouldShowBanner, isFalse);
      expect(degraded.shouldShowBanner, isTrue);
    });

    test('fromOperations carries the degraded flag', () {
      final s = SyncSummary.fromOperations(
        const [],
        online: true,
        durabilityDegraded: true,
      );
      expect(s.durabilityDegraded, isTrue);
      expect(s.shouldShowBanner, isTrue);
    });
  });

  test('SyncCenterController surfaces durabilityDegraded in its summary',
      () async {
    final store = InMemoryReliabilityStore();
    final conn = FakeConnectivity();
    final engine = SyncEngine(
      store: store,
      executor: FakeExecutor((_, __) => ok()),
      connectivity: conn,
      registry: OperationPolicyRegistry.withDefaults(),
    );
    final controller = SyncCenterController(
      store: store,
      connectivity: conn,
      engine: engine,
      durabilityDegraded: true,
    );
    // Let the initial refresh() land.
    await Future<void>.delayed(Duration.zero);

    expect(controller.summary.durabilityDegraded, isTrue);
    controller.dispose();
  });

  test(
      'openReliabilityStore reports degraded=true when the encrypted DB cannot '
      'open in a plugin-less test env (falls back to in-memory)', () async {
    // No sqflite/secure-storage platform channel here → open() throws → fallback.
    final result = await openReliabilityStore();
    expect(result.store, isA<InMemoryReliabilityStore>());
    expect(result.degraded, isTrue);
    expect(result.reason, isNotNull);
  });
}
