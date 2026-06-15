import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/memories/school_memories_screen.dart';
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
        home: const SchoolMemoriesScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows draft events and allows tab switch', (tester) async {
    await _pumpScreen(tester);

    expect(find.byKey(QaTestKeys.schoolMemoriesScreen), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Graduation Preview'), findsOneWidget);

    await tester.tap(find.text('Published').first);
    await tester.pumpAndSettle();

    expect(find.text('Annual Day 2026'), findsOneWidget);
    expect(find.text('Sports Day'), findsOneWidget);
  });

  testWidgets('creates event from dialog using mutation provider',
      (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.byKey(QaTestKeys.schoolMemoriesCreateFab));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(QaTestKeys.schoolMemoriesCreateTitleField),
      'Patrol Created Event',
    );
    await tester.enterText(
      find.byKey(QaTestKeys.schoolMemoriesCreateDescriptionField),
      'Created from widget test',
    );
    await tester.tap(find.byKey(QaTestKeys.schoolMemoriesCreateSubmitButton));
    await tester.pumpAndSettle();
    expect(find.text('Patrol Created Event'), findsOneWidget);
  });
}
