import 'package:akshara_erp/features/control_center/intelligence/platform_intelligence_models.dart';
import 'package:akshara_erp/features/control_center/intelligence/platform_intelligence_providers.dart';
import 'package:akshara_erp/features/control_center/intelligence/platform_intelligence_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
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
          home: const PlatformIntelligenceScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('platform intelligence renders tabbed sections', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Platform Owner'), findsOneWidget);
    expect(find.text('Organization'), findsOneWidget);
    expect(find.text('School Comparison'), findsOneWidget);
    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('Risk'), findsOneWidget);
  });

  testWidgets('revenue tab shows MRR data', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Revenue'));
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
    expect(find.text('MRR'), findsOneWidget);
    expect(find.text('INR 65.8L'), findsOneWidget);
  });

  testWidgets('risk tab renders portfolio risk rows', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Risk'));
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
    expect(find.text('Average Portfolio Risk'), findsOneWidget);
    expect(find.textContaining('Score 36'), findsOneWidget);
  });
}
