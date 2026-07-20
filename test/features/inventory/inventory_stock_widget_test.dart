import 'package:akshara_erp/core/repositories/mock/mock_inventory_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/inventory_finance/inventory_finance_requests.dart';
import 'package:akshara_erp/features/inventory/inventory_stock_provider.dart';
import 'package:akshara_erp/features/inventory/stock/inventory_stock_approvals_screen.dart';
import 'package:akshara_erp/features/inventory/stock/inventory_stock_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1440, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final container = ProviderContainer(
    overrides: erpWidgetTestOverrides([
      userPermissionsProvider.overrideWithValue(
        UserPermissions.forRole(ErpRole.superAdmin),
      ),
      ...overrides,
    ]),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  group('INV-1 issue stock', () {
    testWidgets('issuing below on-hand shows a friendly inline error',
        (tester) async {
      await _pump(tester, const InventoryStockScreen());

      await tester.tap(find.byKey(QaTestKeys.inventoryStockIssueButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockIssueSkuField),
        'NB-A4-200', // seeds at 40 on hand
      );
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockIssueQtyField),
        '9999',
      );
      await tester.tap(find.byKey(QaTestKeys.inventoryStockIssueSubmitButton));
      await tester.pumpAndSettle();

      // Dialog stays open, inline error surfaces the 422 InsufficientStock.
      expect(
        find.byKey(QaTestKeys.inventoryStockIssueErrorText),
        findsOneWidget,
      );
      expect(find.textContaining('Insufficient stock'), findsOneWidget);
      // No success snackbar.
      expect(
        find.byKey(QaTestKeys.inventoryStockIssueSuccessSnackbar),
        findsNothing,
      );
    });

    testWidgets('issuing within on-hand posts the slip', (tester) async {
      await _pump(tester, const InventoryStockScreen());

      await tester.tap(find.byKey(QaTestKeys.inventoryStockIssueButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockIssueSkuField),
        'PEN-BLUE',
      );
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockIssueQtyField),
        '5',
      );
      await tester.tap(find.byKey(QaTestKeys.inventoryStockIssueSubmitButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.inventoryStockIssueSuccessSnackbar),
        findsOneWidget,
      );
    });
  });

  group('INV-3 adjust stock', () {
    testWidgets('adjust_out routes to a pending write-off', (tester) async {
      await _pump(tester, const InventoryStockScreen());

      await tester.tap(find.byKey(QaTestKeys.inventoryStockAdjustButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockAdjustSkuField),
        'PEN-BLUE',
      );
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockAdjustQtyField),
        '3',
      );
      await tester.tap(find.byKey(QaTestKeys.inventoryStockAdjustTypeDropdown));
      await tester.pumpAndSettle();
      await tester
          .tap(find.text('Adjust out / write-off (needs approval)').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockAdjustReasonField),
        'damaged',
      );
      await tester.tap(find.byKey(QaTestKeys.inventoryStockAdjustSubmitButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.inventoryStockAdjustPendingSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('adjust_in applies immediately', (tester) async {
      await _pump(tester, const InventoryStockScreen());

      await tester.tap(find.byKey(QaTestKeys.inventoryStockAdjustButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockAdjustSkuField),
        'PEN-BLUE',
      );
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockAdjustQtyField),
        '5',
      );
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockAdjustReasonField),
        'found',
      );
      await tester.tap(find.byKey(QaTestKeys.inventoryStockAdjustSubmitButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.inventoryStockAdjustAppliedSnackbar),
        findsOneWidget,
      );
    });
  });

  group('INV-2 consumable registry', () {
    testWidgets('adding a consumable with a reorder level saves', (tester) async {
      await _pump(tester, const InventoryStockScreen());

      await tester.tap(find.byKey(QaTestKeys.inventoryStockItemAddButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockItemSkuField),
        'GLUE-STICK',
      );
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockItemNameField),
        'Glue sticks',
      );
      await tester.enterText(
        find.byKey(QaTestKeys.inventoryStockItemReorderField),
        '30',
      );
      await tester.tap(find.byKey(QaTestKeys.inventoryStockItemSubmitButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.inventoryStockItemSavedSnackbar),
        findsOneWidget,
      );
    });
  });

  group('INV-5 register export', () {
    testWidgets('export CSV button is present once the register loads',
        (tester) async {
      final container = await _pump(tester, const InventoryStockScreen());
      // Post an issue so the register has at least one row.
      await container.read(issueStockProvider.notifier).execute(
            const IssueStockRequest(sku: 'PEN-BLUE', quantity: 2),
          );
      // The execute() invalidated the register FutureProvider — let the
      // re-fired future actually resolve before asserting on the button.
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();
      expect(
        find.byKey(QaTestKeys.inventoryStockRegisterExportCsvButton),
        findsOneWidget,
      );
    });
  });

  group('Maker-checker approvals', () {
    testWidgets('a maker cannot self-approve their own write-off',
        (tester) async {
      final container = await _pump(
        tester,
        const InventoryStockApprovalsScreen(),
      );
      // Raise a pending write-off as the current (maker) user.
      final result = await container.read(adjustStockProvider.notifier).execute(
            const AdjustStockRequest(
              sku: 'PEN-BLUE',
              qty: 3,
              movementType: 'adjust_out',
              reason: 'damaged',
            ),
          );
      container.invalidate(inventoryPendingAdjustmentsFutureProvider);
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      final approveKey =
          QaTestKeys.inventoryStockApproveButton(result.adjustmentId!);
      expect(find.byKey(approveKey), findsOneWidget);

      await tester.tap(find.byKey(approveKey));
      await tester.pumpAndSettle();

      // Self-approve blocked → friendly error snackbar, still pending.
      expect(
        find.byKey(QaTestKeys.inventoryStockApproveErrorSnackbar),
        findsOneWidget,
      );
      expect(find.textContaining('cannot approve'), findsOneWidget);
    });

    testWidgets('a different user can approve the write-off', (tester) async {
      final container = await _pump(
        tester,
        const InventoryStockApprovalsScreen(),
      );
      // Maker raises it as one user...
      final result = await container.read(adjustStockProvider.notifier).execute(
            const AdjustStockRequest(
              sku: 'PEN-BLUE',
              qty: 4,
              movementType: 'adjust_out',
              reason: 'damaged',
            ),
          );
      // ...then a DIFFERENT user acts as checker. The screen's decide notifier
      // rebinds the acting user from auth on every call, so instead reassign
      // the raised adjustment's MAKER to a distinct id via the mock test seam —
      // the auth-bound checker then legitimately differs from the maker.
      final repo = container.read(inventoryFinanceRepositoryProvider)
          as MockInventoryFinanceRepository;
      repo.overrideAdjustmentMakerForTest(result.adjustmentId!, 'other_maker');

      container.invalidate(inventoryPendingAdjustmentsFutureProvider);
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(QaTestKeys.inventoryStockApproveButton(result.adjustmentId!)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.inventoryStockApproveSuccessSnackbar),
        findsOneWidget,
      );
    });
  });
}
