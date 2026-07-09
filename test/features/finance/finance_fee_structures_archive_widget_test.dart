import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/fee_structures/finance_fee_structures_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// #6 — Finance fee-structures screen: the backend archive endpoint
/// (`PATCH /finance/fee-structures/:id/archive`) was already built with zero
/// client callers. This proves the client wiring: an Archive action per row,
/// gated behind a destructive confirm dialog, that actually calls the
/// mutation and refreshes the row's status.
void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(WidgetTester tester) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const FinanceFeeStructuresScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

/// The Actions column sits at the far right of a horizontally-scrolling
/// DataTable wider than the desktop viewport — scroll it into view first so
/// the tap actually hits the button instead of a point outside the render tree.
Future<void> _tapArchiveButton(WidgetTester tester) async {
  final finder = find.byKey(
    QaTestKeys.financeArchiveFeeStructureButton('fee_std'),
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

void main() {
  group('#6 · FinanceFeeStructuresScreen archive action', () {
    testWidgets('an active structure shows an Archive action', (tester) async {
      await _pump(tester);

      expect(
        find.byKey(QaTestKeys.financeArchiveFeeStructureButton('fee_std')),
        findsOneWidget,
      );
    });

    testWidgets('tapping Archive opens a destructive confirm dialog',
        (tester) async {
      await _pump(tester);

      await _tapArchiveButton(tester);
      await tester.pumpAndSettle();

      expect(find.text('Archive fee structure'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.financeArchiveFeeStructureConfirmButton),
        findsOneWidget,
      );
    });

    testWidgets(
        'confirming Archive fires the mutation, shows the snackbar, and the '
        'row loses its Archive action', (tester) async {
      await _pump(tester);

      await _tapArchiveButton(tester);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(QaTestKeys.financeArchiveFeeStructureConfirmButton),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.financeFeeStructureArchivedSnackbar),
        findsOneWidget,
      );
      // Archived (status → inactive) — the Archive action for this row is
      // gone since re-archiving an inactive structure is a no-op.
      expect(
        find.byKey(QaTestKeys.financeArchiveFeeStructureButton('fee_std')),
        findsNothing,
      );
    });

    testWidgets('cancelling the confirm dialog does not archive',
        (tester) async {
      await _pump(tester);

      await _tapArchiveButton(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.financeFeeStructureArchivedSnackbar),
        findsNothing,
      );
      expect(
        find.byKey(QaTestKeys.financeArchiveFeeStructureButton('fee_std')),
        findsOneWidget,
      );
    });
  });
}
