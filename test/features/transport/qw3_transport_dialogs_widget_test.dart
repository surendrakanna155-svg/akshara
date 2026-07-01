import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/transport/transport_models.dart';
import 'package:akshara_erp/features/transport/transport_providers.dart';
import 'package:akshara_erp/features/transport/transport_workflow_actions.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';
import '../../test_helpers.dart';

/// QW3 · QA-F-062 — Transport create/confirm dialogs (the dialog-heavy surface).
/// `transport_workflow_actions.dart` was 0% lcov / never pumped. It owns the full
/// set of transport mutation dialogs (route create + activate, attendance record,
/// delay notify, allocation assign/transfer/remove — 7 in total). This suite
/// opens each dialog from a host widget, asserts it renders, confirms it, and
/// asserts the mutation fires (success snackbar) — plus a required-field
/// validation case. Mutations are RBAC-gated (`manageTransport`), exercised via
/// the QA super-admin role matrix. Real demo instances are sourced from the demo
/// repository (`RepositoryQuery.demo`) rather than hand-built models.

/// Overrides used by every test: QA-login env (full permission matrix) + demo
/// repos (the erp default).
List<Override> _overrides() => erpWidgetTestOverrides([
      environmentProvider.overrideWith(
        (ref) => Environment.development.copyWith(enableQaLogin: true),
      ),
    ]);

/// Tolerates debug-only RenderFlex overflow diagnostics emitted while a dialog
/// lays out. Mirrors `suppressGoldenOverflowErrors` in the golden helpers.
/// FINDING (QA-F-062, P2): the route-picker `DropdownButtonFormField` inside the
/// notify-delay / assign / transfer dialogs overflows by ~16px on a 428-wide
/// phone with long demo route names (transport_workflow_actions.dart:212/315/421)
/// — a narrow-phone responsive trim, non-fatal. The dialog still functions; the
/// mutation flow under test is unaffected.
void _tolerateOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// Pumps a host scaffold whose single button invokes [onTap] with a live
/// (context, ref). Returns nothing — the test drives the button + the dialog.
Future<void> _pumpHost(
  WidgetTester tester,
  ProviderContainer container,
  Future<void> Function(BuildContext, WidgetRef) onTap,
) async {
  _tolerateOverflow();
  useMobileViewport(tester);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: ElevatedButton(
                onPressed: () => onTap(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    await initProviderTestPrefs();
    container = ProviderContainer(overrides: _overrides());
  });

  tearDown(() => container.dispose());

  Future<List<TransportRoute>> routes() async =>
      (await container.read(transportRoutesFutureProvider.future)).items;
  Future<List<StudentTransportAllocation>> allocations() async =>
      (await container.read(transportAllocationsFutureProvider.future)).items;
  Future<List<TransportAttendanceRecord>> attendance() async =>
      (await container.read(transportAttendanceFutureProvider.future)).items;

  group('QA-F-062 · Transport workflow dialogs', () {
    testWidgets('Create route dialog confirms and fires the create mutation',
        (tester) async {
      await _pumpHost(
        tester,
        container,
        (context, ref) => showCreateTransportRouteDialog(context, ref),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('New transport route'), findsOneWidget);

      // The route-name field no longer pre-fills QA data (production hygiene) —
      // enter a real name before submitting.
      await tester.enterText(find.byType(TextField), 'Route 12 — East');
      await tester.tap(find.byKey(QaTestKeys.transportSaveRouteDialogButton));
      await settleRiverpodFutures(tester);
      await tester.pump();

      expect(
        find.byKey(QaTestKeys.transportRouteSuccessSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('Activate route dialog confirms and fires the activate mutation',
        (tester) async {
      // A draft route is required (active routes short-circuit the dialog).
      final draft = (await routes())
          .firstWhere((r) => r.status == TransportRouteStatus.draft);

      await _pumpHost(
        tester,
        container,
        (context, ref) =>
            showActivateTransportRouteDialog(context, ref, route: draft),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Activate route'), findsOneWidget);

      await tester.tap(find.byKey(QaTestKeys.transportActivateRouteDialogButton));
      await settleRiverpodFutures(tester);
      await tester.pump();

      expect(
        find.byKey(QaTestKeys.transportRouteActivatedSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('Record attendance dialog confirms and fires the mutation',
        (tester) async {
      final record = (await attendance()).first;

      await _pumpHost(
        tester,
        container,
        (context, ref) =>
            showRecordTransportAttendanceDialog(context, ref, record: record),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mark '), findsOneWidget);

      await tester.tap(
        find.byKey(QaTestKeys.transportMarkAttendanceDialogSubmitButton),
      );
      await settleRiverpodFutures(tester);
      await tester.pump();

      expect(
        find.byKey(QaTestKeys.transportAttendanceRecordedSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('Notify delay dialog validates message then fires the mutation',
        (tester) async {
      final allRoutes = await routes();

      await _pumpHost(
        tester,
        container,
        (context, ref) =>
            showNotifyRouteDelayDialog(context, ref, routes: allRoutes),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Notify parents of delay'), findsOneWidget);

      // Empty message → validation blocks the mutation (warning snackbar).
      await tester.tap(find.byKey(QaTestKeys.transportNotifyDelayDialogSubmitButton));
      await tester.pump();
      expect(find.text('Enter a delay message before notifying.'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.transportNotifyDelaySuccessSnackbar),
        findsNothing,
      );
      // Clear the lingering warning snackbar before the success path.
      ScaffoldMessenger.of(
        tester.element(find.text('open')),
      ).clearSnackBars();
      await tester.pump();

      // Re-open, enter a message → mutation fires.
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Bus running 15 min late',
      );
      await tester.pump();
      await tester.tap(find.byKey(QaTestKeys.transportNotifyDelayDialogSubmitButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.transportNotifyDelaySuccessSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('Assign dialog validates stops then fires the assign mutation',
        (tester) async {
      // The assign flow targets an UNASSIGNED student (assigned ones throw).
      final allocation =
          (await allocations()).firstWhere((a) => a.routeId.isEmpty);
      final allRoutes = await routes();

      await _pumpHost(
        tester,
        container,
        (context, ref) => showAssignStudentTransportDialog(
          context,
          ref,
          allocation: allocation,
          routes: allRoutes,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Assign '), findsOneWidget);

      // Pickup stop empty by default → validation blocks the mutation.
      await tester.tap(find.byKey(QaTestKeys.transportAssignDialogSubmitButton));
      await tester.pump();
      expect(find.text('Pickup and drop stops are required.'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.transportAssignSuccessSnackbar),
        findsNothing,
      );
      // Clear the lingering warning snackbar before the success path.
      ScaffoldMessenger.of(
        tester.element(find.text('open')),
      ).clearSnackBars();
      await tester.pump();

      // Re-open, fill the pickup stop (drop defaults to Main Gate) → fires.
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.ancestor(
          of: find.text('Pickup stop'),
          matching: find.byType(TextField),
        ),
        'Gate 2',
      );
      await tester.pump();
      await tester.tap(find.byKey(QaTestKeys.transportAssignDialogSubmitButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.transportAssignSuccessSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('Transfer dialog confirms and fires the transfer mutation',
        (tester) async {
      // Transfer targets an already-assigned student onto another active route.
      final allocation =
          (await allocations()).firstWhere((a) => a.routeId.isNotEmpty);
      final allRoutes = await routes();

      await _pumpHost(
        tester,
        container,
        (context, ref) => showTransferStudentTransportDialog(
          context,
          ref,
          allocation: allocation,
          routes: allRoutes,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Transfer '), findsOneWidget);

      // Pickup/drop pre-filled from the existing allocation → confirm directly.
      await tester.tap(find.byKey(QaTestKeys.transportTransferDialogSubmitButton));
      await settleRiverpodFutures(tester);
      await tester.pump();

      expect(
        find.byKey(QaTestKeys.transportTransferSuccessSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('Remove dialog confirms and fires the remove mutation',
        (tester) async {
      final allocation =
          (await allocations()).firstWhere((a) => a.routeId.isNotEmpty);

      await _pumpHost(
        tester,
        container,
        (context, ref) => removeStudentFromRoute(context, ref, allocation),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Remove from route'), findsOneWidget);

      await tester.tap(find.byKey(QaTestKeys.transportRemoveDialogSubmitButton));
      await settleRiverpodFutures(tester);
      await tester.pump();

      expect(
        find.byKey(QaTestKeys.transportRemoveSuccessSnackbar),
        findsOneWidget,
      );
    });
  });
}
