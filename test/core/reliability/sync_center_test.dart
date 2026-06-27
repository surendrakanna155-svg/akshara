import 'package:akshara_erp/core/reliability/model/mutation_envelope.dart';
import 'package:akshara_erp/core/reliability/model/mutation_request.dart';
import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:akshara_erp/core/reliability/reliability_providers.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/reliability/sync/sync_engine.dart';
import 'package:akshara_erp/core/reliability/sync_center/sync_banner.dart';
import 'package:akshara_erp/core/reliability/sync_center/sync_center_controller.dart';
import 'package:akshara_erp/core/reliability/sync_center/sync_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reliability_fakes.dart';

MutationEnvelope _op(String id, SyncStatus status) => MutationEnvelope(
      request: MutationRequest(
          type: 'attendance.mark', method: 'POST', path: '/a', idempotencyKey: id),
      status: status,
      createdAt: DateTime.utc(2026, 6, 27),
    );

void main() {
  group('SyncSummary.fromOperations', () {
    test('counts each status and flags banner correctly', () {
      final summary = SyncSummary.fromOperations(
        <MutationEnvelope>[
          _op('a', SyncStatus.pending),
          _op('b', SyncStatus.pending),
          _op('c', SyncStatus.conflict),
          _op('d', SyncStatus.confirmed),
          _op('e', SyncStatus.failed),
        ],
        online: true,
      );
      expect(summary.pending, 2);
      expect(summary.conflicts, 1);
      expect(summary.failed, 1);
      expect(summary.outstanding, 4);
      expect(summary.hasConflicts, isTrue);
      expect(summary.shouldShowBanner, isTrue);
    });

    test('online with no outstanding hides the banner', () {
      final summary = SyncSummary.fromOperations(
        <MutationEnvelope>[_op('d', SyncStatus.confirmed)],
        online: true,
      );
      expect(summary.shouldShowBanner, isFalse);
    });
  });

  group('SyncBanner widget', () {
    Future<SyncCenterController> controllerWith({
      required bool online,
      List<MutationEnvelope> ops = const <MutationEnvelope>[],
    }) async {
      final store = InMemoryReliabilityStore();
      for (final MutationEnvelope op in ops) {
        await store.putOperation(op);
      }
      final conn = FakeConnectivity(online: online);
      final engine = SyncEngine(
        store: store,
        executor: FakeExecutor((_, __) => ok()),
        connectivity: conn,
        registry: OperationPolicyRegistry(),
      );
      final controller = SyncCenterController(
          store: store, connectivity: conn, engine: engine);
      await controller.refresh();
      return controller;
    }

    testWidgets('shows offline message when offline', (tester) async {
      final controller = await controllerWith(online: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            syncCenterControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: SyncBanner())),
        ),
      );
      await tester.pump();
      expect(find.textContaining('offline'), findsOneWidget);
    });

    testWidgets('is hidden when online with nothing outstanding',
        (tester) async {
      final controller = await controllerWith(online: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            syncCenterControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: SyncBanner())),
        ),
      );
      await tester.pump();
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.textContaining('offline'), findsNothing);
    });
  });
}
