// PRC-A client — GatePassesScreen: the raise FAB is gated on requestGatePass,
// the quick Verify action is gated on verifyGatePass and only ever shown on a
// verifiable (approved, not expired) pass, and Cancel is gated on
// approveGatePass. Also asserts the screen never renders an OTP anywhere.

import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/gate_pass/gate_pass_datasource.dart';
import 'package:akshara_erp/features/gate_pass/gate_pass_models.dart';
import 'package:akshara_erp/features/gate_pass/gate_pass_providers.dart';
import 'package:akshara_erp/features/gate_pass/gate_passes_screen.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

/// A datasource returning a fixed list — no network.
class _FixedDataSource implements GatePassDataSource {
  _FixedDataSource(this._items);
  final List<GatePass> _items;

  @override
  Future<List<GatePass>> list({String? status}) async => _items;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

GatePass _pass({String status = 'pending', bool hasCredential = false}) => GatePass(
      id: 'gp-1',
      studentId: 'stu-1',
      passType: 'early_pickup',
      reason: 'dentist appointment',
      requestedBy: 'user-1',
      pickupPersonName: 'Asha Rao',
      pickupPersonRelation: 'Mother',
      pickupPersonPhone: '9999999999',
      scheduledAt: '2026-07-15T10:00:00Z',
      status: status,
      rawStatus: status,
      hasCredential: hasCredential,
    );

// A real (if minimal) GoRouter is required: `ManagePermissionGuard` (behind
// every AksharaManageAction on this screen) calls `GoRouterState.of(context)`
// when a permission check FAILS, to audit-log the denied route — a bare
// `MaterialApp` has no GoRouter ancestor for that call to find, and every
// permission-denied assertion here would blow up with a GoError instead of
// exercising the gate. Mirrors test/features/finance/
// finance_award_fee_reduction_widget_test.dart, which documents the same trap.
Future<void> _pump(
  WidgetTester tester, {
  required List<GatePass> items,
  required Set<Permission> perms,
}) async {
  final router = GoRouter(
    initialLocation: RouteNames.gatePasses,
    routes: [
      GoRoute(
        path: RouteNames.gatePasses,
        builder: (context, state) => const GatePassesScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      // erpWidgetTestOverrides supplies the base app providers this widget tree
      // reaches for (sharedPreferences, auth state, ...) — without it
      // ManagePermissionGuard throws "sharedPreferencesProvider is
      // uninitialized" before any gate is ever exercised.
      overrides: erpWidgetTestOverrides([
        gatePassDataSourceProvider.overrideWithValue(_FixedDataSource(items)),
        rbacServiceProvider.overrideWithValue(
          RbacService(
            UserPermissions(role: ErpRole.schoolAdmin, permissionSet: PermissionSet.from(perms)),
          ),
        ),
      ]),
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  // ManagePermissionGuard reaches for sharedPreferencesProvider (to record a
  // denied-access audit); erpWidgetTestOverrides does not seed it on its own.
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  testWidgets('a maker with requestGatePass sees the raise FAB', (tester) async {
    await _pump(tester, items: [_pass()], perms: {Permission.requestGatePass});
    expect(find.byKey(const Key('gate-pass-raise-button')), findsOneWidget);
  });

  testWidgets('a viewer WITHOUT requestGatePass never sees the raise FAB', (tester) async {
    await _pump(tester, items: [_pass()], perms: {});
    expect(find.byKey(const Key('gate-pass-raise-button')), findsNothing);
  });

  testWidgets('an empty queue shows the empty state, not a spinner or error', (tester) async {
    await _pump(tester, items: const [], perms: {Permission.requestGatePass});
    expect(find.text('No gate passes yet.'), findsOneWidget);
  });

  testWidgets(
      'the quick Verify action appears on an approved pass for a holder of verifyGatePass',
      (tester) async {
    await _pump(
      tester,
      items: [_pass(status: 'approved', hasCredential: true)],
      perms: {Permission.verifyGatePass},
    );
    expect(find.byKey(const Key('gate-pass-verify-action-gp-1')), findsOneWidget);
  });

  testWidgets('the quick Verify action is hidden without verifyGatePass, even when approved',
      (tester) async {
    await _pump(
      tester,
      items: [_pass(status: 'approved', hasCredential: true)],
      perms: {Permission.approveGatePass},
    );
    expect(find.byKey(const Key('gate-pass-verify-action-gp-1')), findsNothing);
  });

  testWidgets('the quick Verify action never appears on a pending (not yet approved) pass',
      (tester) async {
    await _pump(
      tester,
      items: [_pass(status: 'pending')],
      perms: {Permission.verifyGatePass},
    );
    expect(find.byKey(const Key('gate-pass-verify-action-gp-1')), findsNothing);
  });

  testWidgets('the quick Verify action never appears on an expired (lazily-computed) pass',
      (tester) async {
    await _pump(
      tester,
      items: [_pass(status: 'expired')],
      perms: {Permission.verifyGatePass},
    );
    expect(find.byKey(const Key('gate-pass-verify-action-gp-1')), findsNothing);
  });

  testWidgets('Cancel in the detail dialog is gated on approveGatePass', (tester) async {
    await _pump(
      tester,
      items: [_pass(status: 'pending')],
      perms: {Permission.requestGatePass},
    );
    await tester.tap(find.byKey(const Key('gate-pass-tile-gp-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gate-pass-cancel-button')), findsNothing);
  });

  testWidgets('Cancel is offered to a holder of approveGatePass on a pending pass', (tester) async {
    await _pump(
      tester,
      items: [_pass(status: 'pending')],
      perms: {Permission.approveGatePass},
    );
    await tester.tap(find.byKey(const Key('gate-pass-tile-gp-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gate-pass-cancel-button')), findsOneWidget);
  });

  testWidgets('the screen never renders an OTP anywhere — the API never returns one',
      (tester) async {
    await _pump(
      tester,
      items: [_pass(status: 'approved', hasCredential: true)],
      perms: {Permission.verifyGatePass, Permission.approveGatePass, Permission.requestGatePass},
    );
    expect(find.textContaining('OTP', findRichText: true), findsNothing);
    expect(find.byKey(const Key('gate-pass-tile-gp-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gate-pass-verify-action-gp-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gate-pass-verify-dialog')), findsOneWidget);
    // The verify surface only ever offers a field to TYPE IN the code — never
    // a display of one.
    expect(find.byKey(const Key('gate-pass-verify-otp-field')), findsOneWidget);
    expect(find.textContaining('OTP', findRichText: true), findsNothing);
  });
}
