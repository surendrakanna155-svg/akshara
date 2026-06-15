import 'package:akshara_erp/features/finance/payments/finance_offline_payments_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const FinanceOfflinePaymentsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows pending offline payments by default', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Reconciled'), findsOneWidget);
    expect(find.text('Offline payment records'), findsOneWidget);
    expect(find.text('Arjun Patel'), findsWidgets);
  });

  testWidgets('opens record offline payment dialog from FAB', (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Record offline payment'), findsWidgets);
    expect(find.text('Invoice ID'), findsOneWidget);
  });
}
