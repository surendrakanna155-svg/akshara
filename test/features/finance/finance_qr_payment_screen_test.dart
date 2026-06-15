import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/finance_qr_payment_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('FinanceQrPaymentScreen renders QR payment flow', (tester) async {
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides(),
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const FinanceQrPaymentScreen(
            initialInvoiceId: 'inv_1',
            initialAmount: '6000',
          ),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();

    expect(find.text('QR Payment'), findsOneWidget);
    expect(find.byKey(QaTestKeys.financeQrInvoiceField), findsOneWidget);
    expect(find.byKey(QaTestKeys.financeQrAmountField), findsOneWidget);
    expect(find.byKey(QaTestKeys.financeGenerateQrButton), findsOneWidget);
    expect(find.text('Generate a QR to start UPI collection.'), findsOneWidget);
  });
}
