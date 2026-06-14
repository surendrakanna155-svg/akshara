import 'package:akshara_erp/features/education/education_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  testWidgets('EducationScreen renders all tabs', (tester) async {
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
          home: const EducationScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();

    expect(find.text('Education Suite'), findsOneWidget);
    expect(find.text('Question Papers'), findsOneWidget);
    expect(find.text('Question Bank'), findsOneWidget);
    expect(find.text('Homework'), findsOneWidget);
    expect(find.text('Report Remarks'), findsOneWidget);
  });
}
