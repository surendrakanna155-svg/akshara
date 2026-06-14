import 'package:akshara_erp/features/communication/broadcast_admin_screen.dart';
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

Future<void> _pumpScreen(WidgetTester tester) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const BroadcastAdminScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Broadcast admin renders all tabs', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Compose'), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
  });

  testWidgets('Sending broadcast adds entry in history', (tester) async {
    await _pumpScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Fee alert');
    await tester.enterText(
      find.widgetWithText(TextField, 'Body'),
      'Please clear dues before Friday',
    );
    await tester.tap(find.text('Send broadcast'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Fee alert'), findsOneWidget);
  });
}
