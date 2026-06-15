import 'package:akshara_erp/features/parent_meetings/parent_meetings_screen.dart';
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
        home: const ParentMeetingsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders meeting list and create action', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Parent Meeting Summary'), findsOneWidget);
    expect(find.text('Create Meeting'), findsOneWidget);
    expect(find.textContaining('Aarav Nair'), findsOneWidget);
  });

  testWidgets('opens create dialog and creates record', (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Create Meeting'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Student ID'), 'STU_2044');
    await tester.enterText(
        find.widgetWithText(TextField, 'Student Name'), 'Neha Reddy');
    await tester.enterText(
        find.widgetWithText(TextField, 'Parent Name'), 'Suresh Reddy');
    await tester.enterText(
        find.widgetWithText(TextField, 'Teacher Name'), 'Mr. Kumar');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Neha Reddy'), findsOneWidget);
  });
}
