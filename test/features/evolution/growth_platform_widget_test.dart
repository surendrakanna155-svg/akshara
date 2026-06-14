import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/evolution/growth_platform_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

Future<void> pumpGrowthScreen(WidgetTester tester) async {
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
        home: const GrowthPlatformScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('GrowthPlatformScreen', () {
    testWidgets('renders tabs and dashboard metrics', (tester) async {
      await pumpGrowthScreen(tester);

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Campaigns'), findsOneWidget);
      expect(find.text('Inquiries'), findsWidgets);
      expect(find.text('Conversion funnel'), findsOneWidget);
      expect(find.text('Active campaigns'), findsOneWidget);
    });

    testWidgets('opens create campaign dialog fields', (tester) async {
      await pumpGrowthScreen(tester);

      await tester.tap(find.byKey(QaTestKeys.growthCreateCampaignButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.growthCampaignNameField), findsOneWidget);
      expect(find.byKey(QaTestKeys.growthCampaignChannelField), findsOneWidget);
      expect(find.byKey(QaTestKeys.growthCampaignBudgetField), findsOneWidget);
      expect(find.byKey(QaTestKeys.growthCampaignAudienceField), findsOneWidget);
      expect(find.byKey(QaTestKeys.growthCampaignScheduleButton), findsOneWidget);
    });

    testWidgets('shows inquiry convert action', (tester) async {
      await pumpGrowthScreen(tester);

      await tester.tap(find.byType(Tab).at(2));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.growthConvertInquiryButton('inq_1')), findsOneWidget);
    });
  });
}
