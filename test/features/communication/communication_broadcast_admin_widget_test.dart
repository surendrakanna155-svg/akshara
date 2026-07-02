import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/communication/broadcast_admin_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1400);
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

  testWidgets('audience picker reveals class + section on class audience',
      (tester) async {
    await _pumpScreen(tester);

    // Class fields hidden for the default (all_parents) audience.
    expect(
      find.byKey(QaTestKeys.communicationAudienceClassField),
      findsNothing,
    );

    // Select "Class parents" from the audience dropdown.
    await tester.tap(find.byKey(QaTestKeys.communicationAudiencePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Class parents').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(QaTestKeys.communicationAudienceClassField),
      findsOneWidget,
    );
    expect(
      find.byKey(QaTestKeys.communicationAudienceSectionField),
      findsOneWidget,
    );
  });

  testWidgets('class audience without a class blocks send with inline error',
      (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.byKey(QaTestKeys.communicationAudiencePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Class students').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Fee alert');
    await tester.tap(find.byKey(QaTestKeys.communicationBroadcastSendButton));
    await tester.pumpAndSettle();

    expect(find.text('Class is required'), findsOneWidget);
  });

  testWidgets('sending broadcast + opening report shows counts and resend',
      (tester) async {
    await _pumpScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Fee alert');
    await tester.enterText(
      find.widgetWithText(TextField, 'Body'),
      'Please clear dues before Friday',
    );
    await tester.tap(find.byKey(QaTestKeys.communicationBroadcastSendButton));
    await tester.pumpAndSettle();
    // Let the "Broadcast sent" snackbar time out so it does not queue ahead of
    // the later "N resent" snackbar.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // The broadcast lands in History.
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Fee alert'), findsOneWidget);

    // Tapping the row opens the report with counts + a resend action.
    await tester.tap(find.text('Fee alert'));
    await tester.pumpAndSettle();

    expect(find.text('Broadcast report'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);

    await tester
        .tap(find.byKey(QaTestKeys.communicationBroadcastReportResendButton));
    await tester.pump(); // start the async resend
    await tester.pump(const Duration(milliseconds: 400)); // let snackbar appear
    // A "N resent" snackbar confirms the resend fired.
    expect(find.textContaining('resent'), findsOneWidget);
  });
}
