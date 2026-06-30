import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:akshara_erp/core/reliability/reliability_providers.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/reliability/sync/sync_engine.dart';
import 'package:akshara_erp/core/reliability/sync_center/sync_banner.dart';
import 'package:akshara_erp/core/reliability/sync_center/sync_center_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reliability_fakes.dart';

/// QW6 · QA-X-005 — the global offline banner appears AND clears on a live
/// connectivity *change* (not just two static snapshots). Phase 0 shipped the
/// connectivity listener (`ConnectivityServiceImpl`) + `SyncBanner`; this row
/// proves the banner reacts to a transition and shows the offline affordance.
void main() {
  testWidgets('banner appears on going offline and clears on reconnect',
      (tester) async {
    final store = InMemoryReliabilityStore();
    final conn = FakeConnectivity(online: true);
    final engine = SyncEngine(
      store: store,
      executor: FakeExecutor((_, __) => ok()),
      connectivity: conn,
      registry: OperationPolicyRegistry(),
    );
    final controller =
        SyncCenterController(store: store, connectivity: conn, engine: engine);
    await controller.refresh();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          syncCenterControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncBanner())),
      ),
    );
    await tester.pump();

    // Online, nothing outstanding → banner hidden.
    expect(find.byIcon(Icons.cloud_off), findsNothing);
    expect(find.textContaining('offline'), findsNothing);

    // Connectivity drops → banner appears with the offline icon + message.
    conn.setOnline(false);
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);

    // Reconnect → banner clears (nothing outstanding).
    conn.setOnline(true);
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsNothing);
    expect(find.textContaining('offline'), findsNothing);

    await conn.dispose();
  });
}
