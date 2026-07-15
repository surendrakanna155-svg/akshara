// STEP-5 — P0 money-honesty fix (PRC-A cap 71): widget coverage for the
// invoice-scoped fee-reduction maker-checker. The maker dialog
// (`showAssignFeeConcessionDialog`) requires a reason + a selected open
// invoice before it will propose an award (moves no money); the checker
// section's Approve/Reject/Reverse actions are gated behind
// `Permission.approveFeeConcession`.

import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/discounts/finance_discounts_provider.dart';
import 'package:akshara_erp/features/finance/discounts/finance_discounts_screen.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_mutations_provider.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

// A real (if minimal) GoRouter is required: `ManagePermissionGuard` (behind
// every AksharaManageAction on this screen) calls `GoRouterState.of(context)`
// when a permission check FAILS, to audit-log the denied route — a bare
// `MaterialApp` has no GoRouter ancestor for that call to find.
Future<void> _pump(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  _useDesktopViewport(tester);
  final router = GoRouter(
    initialLocation: '/finance/discounts',
    routes: [
      GoRoute(
        path: '/finance/discounts',
        builder: (context, state) => const FinanceDiscountsScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
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
  setUpAll(() async {
    // Denied-access auditing (hit whenever a role lacking manageFinance /
    // approveFeeConcession renders a gated action) reads sharedPreferencesProvider.
    await initProviderTestPrefs();
  });

  group('STEP-5 · Award (maker) dialog', () {
    testWidgets(
        'requires a reason before proposing, then proposes against the '
        'selected open invoice (moves no money)', (tester) async {
      await _pump(
        tester,
        overrides: [
          // Only financeAdmin holds Permission.assignScholarship in this
          // build (see role_permissions.dart) — the "Award" button is gated
          // on it.
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );

      final awardButton = find.byKey(QaTestKeys.financeAssignConcessionButton);
      expect(awardButton, findsOneWidget);
      await tester.ensureVisible(awardButton);
      await tester.tap(awardButton);
      await tester.pumpAndSettle();

      expect(find.text('Award a scholarship or discount'), findsOneWidget);

      // No reason entered yet → the confirm guard keeps the dialog open.
      await tester.tap(
        find.byKey(QaTestKeys.financeAssignConcessionSubmitButton),
      );
      await tester.pumpAndSettle();
      expect(find.text('Award a scholarship or discount'), findsOneWidget);

      await tester.enterText(
        find.byKey(QaTestKeys.financeAwardReasonField),
        'Merit scholarship',
      );
      await tester.pump();

      await tester.tap(
        find.byKey(QaTestKeys.financeAssignConcessionSubmitButton),
      );
      await tester.pumpAndSettle();

      // Dialog closed + confirmation shown.
      expect(find.text('Award a scholarship or discount'), findsNothing);
      expect(
        find.byKey(QaTestKeys.financeAssignConcessionSuccessSnackbar),
        findsOneWidget,
      );

      // The mutation actually reached proposeScholarshipAward with the
      // dialog's (defaulted) selected invoice — inv_1 is acct_1's only open
      // invoice in the mock seed data — and it is `pending` / moves no money.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FinanceDiscountsScreen)),
      );
      final proposed = container.read(proposeScholarshipAwardProvider).value;
      expect(proposed, isNotNull);
      expect(proposed!.status, FeeReductionStatus.pending);
      expect(proposed.invoiceId, 'inv_1');
      expect(proposed.appliedAmount, '0');
    });
  });

  group('STEP-5 · Pending awards (checker) gating', () {
    const testReduction = FeeReduction(
      id: 'fred_test',
      sourceKind: FeeReductionSourceKind.scholarship,
      scholarshipId: 'sch_1',
      studentId: 'stu_1',
      invoiceId: 'inv_1',
      studentAccountId: 'acct_1',
      reductionKind: FeeReductionKind.percent,
      percent: '25',
      status: FeeReductionStatus.pending,
      reason: 'Merit scholarship',
      createdBy: 'finance_demo',
      createdAt: '2026-07-15T00:00:00.000Z',
      updatedAt: '2026-07-15T00:00:00.000Z',
    );

    testWidgets('Approve action is hidden without approveFeeConcession',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          financeFeeReductionsFutureProvider.overrideWith(
            (ref) async => [testReduction],
          ),
          // No finance permissions at all.
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );

      expect(find.text('Pending awards'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.financeFeeReductionApproveButton('fred_test')),
        findsNothing,
      );
      expect(
        find.byKey(QaTestKeys.financeFeeReductionRejectButton('fred_test')),
        findsNothing,
      );
    });

    testWidgets('Approve action is shown with approveFeeConcession',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          financeFeeReductionsFutureProvider.overrideWith(
            (ref) async => [testReduction],
          ),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );

      expect(find.text('Pending awards'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.financeFeeReductionApproveButton('fred_test')),
        findsOneWidget,
      );
    });
  });
}
