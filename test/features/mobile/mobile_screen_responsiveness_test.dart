import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_screen.dart';
import 'package:akshara_erp/features/student_app/dashboard/student_dashboard_screen.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

Future<void> pumpMobileShell(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('Mobile UX audit — phone layouts', () {
    testWidgets('Parent dashboard iPhone 390x844 no overflow', (tester) async {
      await pumpMobileShell(tester, const ParentDashboardScreen());
      expect(tester.takeException(), isNull);
      expect(find.byType(ParentDashboardScreen), findsOneWidget);
    });

    testWidgets('Teacher dashboard Android 412x915 no overflow', (tester) async {
      await pumpMobileShell(
        tester,
        const TeacherDashboardScreen(),
        size: const Size(412, 915),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Student dashboard iPhone 428x926 no overflow', (tester) async {
      await pumpMobileShell(
        tester,
        const StudentDashboardScreen(),
        size: const Size(428, 926),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Mobile UX audit — tablet layouts', () {
    testWidgets('Parent dashboard tablet 834x1194 no overflow', (tester) async {
      await pumpMobileShell(
        tester,
        const ParentDashboardScreen(),
        size: const Size(834, 1194),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
