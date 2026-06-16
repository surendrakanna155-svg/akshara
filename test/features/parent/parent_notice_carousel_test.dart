import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/school_config/school_configuration_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../golden/golden_test_helpers.dart';

void main() {
  testWidgets('notice n3 is first in carousel without horizontal scroll', (tester) async {
    await pumpGoldenDashboard(
      tester,
      screen: const ParentDashboardScreen(),
      viewport: GoldenViewports.mobile390,
      extraOverrides: [
        schoolConfigurationProvider.overrideWith(_DemoSchoolConfig.new),
      ],
    );

    await tester.ensureVisible(find.byKey(QaTestKeys.parentNoticeCarousel));
    expect(find.byKey(QaTestKeys.parentDashboardNotice('n3')), findsOneWidget);
  });

  testWidgets('notice n1 is reachable after horizontal carousel scroll', (tester) async {
    await pumpGoldenDashboard(
      tester,
      screen: const ParentDashboardScreen(),
      viewport: GoldenViewports.mobile390,
      extraOverrides: [
        schoolConfigurationProvider.overrideWith(_DemoSchoolConfig.new),
      ],
    );

    await tester.ensureVisible(find.byKey(QaTestKeys.parentNoticeCarousel));
    final horizontal = find.descendant(
      of: find.byKey(QaTestKeys.parentNoticeCarousel),
      matching: find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      ),
    );
    await tester.drag(horizontal, const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.parentDashboardNotice('n1')), findsOneWidget);
  });

  testWidgets('notice n3 tap invokes notice_n3 navigation action', (tester) async {
    String? actionId;
    await pumpGoldenDashboard(
      tester,
      screen: ParentDashboardScreen(onNavigate: (id) => actionId = id),
      viewport: GoldenViewports.mobile390,
      extraOverrides: [
        schoolConfigurationProvider.overrideWith(_DemoSchoolConfig.new),
      ],
    );

    await tester.ensureVisible(find.byKey(QaTestKeys.parentNoticeCarousel));

    final inkWell = find.descendant(
      of: find.byKey(QaTestKeys.parentDashboardNotice('n3')),
      matching: find.byType(InkWell),
    );
    await tester.tap(inkWell);
    await tester.pump();
    expect(actionId, 'notice_n3');
  });
}

class _DemoSchoolConfig extends SchoolConfigurationNotifier {
  @override
  SchoolConfiguration build() => SchoolConfiguration.demoDefault();
}
