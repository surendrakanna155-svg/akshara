import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/defaulters/finance_defaulters_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// C1 · FIN-R2 — the telecaller call queue on the defaulters screen, and the
/// completion round-trip: pick from the queue → log an outcome → the queue
/// re-ranks live (that student drops from "Not yet contacted" to "Recently
/// contacted"), all through the real mock recovery repo.
void main() {
  void useTallDesktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pump(WidgetTester tester) async {
    useTallDesktop(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides(),
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const FinanceDefaultersScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('FIN-R2 · call queue renders ranked entries with reasons',
      (tester) async {
    await pump(tester);

    expect(find.byKey(QaTestKeys.financeCallQueueSection), findsOneWidget);
    expect(find.text('Call queue'), findsOneWidget);
    // Every demo defaulter is overdue and not yet contacted this session.
    expect(find.text('Not yet contacted'), findsWidgets);
  });

  testWidgets('FIN-R2 · logging a contact from the queue re-ranks it live',
      (tester) async {
    await pump(tester);

    // Ananya Reddy (def_2) starts as "Not yet contacted" (no promise, no
    // prior contact) — def_1/def_3 carry seeded promises that outrank contact.
    expect(find.text('Not yet contacted'), findsOneWidget);
    final logButton = find.byKey(QaTestKeys.financeCallQueueLogButton('def_2'));
    await tester.ensureVisible(logButton);
    await tester.tap(logButton);
    await tester.pumpAndSettle();

    // The shared log-contact dialog opens for that student.
    expect(find.text('Log contact — Ananya Reddy'), findsOneWidget);
    await tester.tap(find.byKey(QaTestKeys.financeLogContactSubmitButton));
    await tester.pumpAndSettle();
    expect(find.byKey(QaTestKeys.financeLogContactSuccessSnackbar),
        findsOneWidget);

    // The queue re-ranks: def_1 is now "Recently contacted".
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
    expect(find.text('Recently contacted'), findsOneWidget);
  });
}
