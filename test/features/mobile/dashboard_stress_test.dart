import 'package:akshara_erp/features/finance/dashboard/finance_dashboard_screen.dart';
import 'package:akshara_erp/features/inventory/dashboard/inventory_dashboard_screen.dart';
import 'package:akshara_erp/features/management/dashboard/management_dashboard_screen.dart';
import 'package:akshara_erp/features/management/intelligence/intelligence_hub_screen.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_screen.dart';
import 'package:akshara_erp/features/student/dashboard/student_dashboard_provider.dart';
import 'package:akshara_erp/features/student/dashboard/student_dashboard_screen.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_provider.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../golden/golden_test_helpers.dart';
import '../../helpers/stress_fixtures.dart';
import '../../test_helpers.dart';

Future<void> pumpStressScreen(
  WidgetTester tester, {
  required Widget screen,
  required Size viewport,
  double textScale = 1.0,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        parentDashboardLoadingProvider.overrideWith((ref) => false),
        teacherDashboardLoadingProvider.overrideWith((ref) => false),
        studentDashboardLoadingProvider.overrideWith((ref) => false),
        ...overrides,
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('Phase 1 — responsive device stress', () {
    final mobileScreens = <Widget>[
      const ParentDashboardScreen(),
      const TeacherDashboardScreen(),
      const StudentDashboardScreen(),
    ];

    for (final viewport in StressFixtures.stressViewports) {
      for (final screen in mobileScreens) {
        testWidgets(
          '${screen.runtimeType} ${viewport.label} no overflow',
          (tester) async {
            await pumpStressScreen(
              tester,
              screen: screen,
              viewport: viewport.size,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('Phase 2 — long data stress', () {
    for (final viewport in [
      const Size(360, 640),
      const Size(390, 844),
      const Size(428, 926),
    ]) {
      testWidgets('Parent long data ${viewport.width}x${viewport.height}', (
        tester,
      ) async {
        await pumpStressScreen(
          tester,
          screen: const ParentDashboardScreen(),
          viewport: viewport,
          overrides: [
            parentDashboardProvider.overrideWith(
              (ref) => StressFixtures.stressParentDashboard(),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('Teacher long data ${viewport.width}x${viewport.height}', (
        tester,
      ) async {
        await pumpStressScreen(
          tester,
          screen: const TeacherDashboardScreen(),
          viewport: viewport,
          overrides: [
            teacherDashboardProvider.overrideWith(
              (ref) => StressFixtures.stressTeacherDashboard(),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('Student long data ${viewport.width}x${viewport.height}', (
        tester,
      ) async {
        await pumpStressScreen(
          tester,
          screen: const StudentDashboardScreen(),
          viewport: viewport,
          overrides: [
            studentDashboardProvider.overrideWith(
              (ref) => StressFixtures.stressStudentDashboard(),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Phase 3 — empty subsection states', () {
    testWidgets('Parent empty notices and events show guidance', (
      tester,
    ) async {
      await pumpStressScreen(
        tester,
        screen: const ParentDashboardScreen(),
        viewport: const Size(390, 844),
        overrides: [
          parentDashboardProvider.overrideWith(
            (ref) => StressFixtures.emptyParentDashboard(),
          ),
        ],
      );
      expect(find.text('No school notices right now.'), findsOneWidget);
      expect(find.text('No upcoming events scheduled.'), findsOneWidget);
    });

    testWidgets('Teacher empty schedule and tasks show guidance', (
      tester,
    ) async {
      await pumpStressScreen(
        tester,
        screen: const TeacherDashboardScreen(),
        viewport: const Size(390, 844),
        overrides: [
          teacherDashboardProvider.overrideWith(
            (ref) => StressFixtures.emptyTeacherDashboard(),
          ),
        ],
      );
      expect(find.text('No classes scheduled for today.'), findsOneWidget);
      expect(find.text('All caught up — no pending tasks.'), findsOneWidget);
    });

    testWidgets('Student empty homework and schedule show guidance', (
      tester,
    ) async {
      await pumpStressScreen(
        tester,
        screen: const StudentDashboardScreen(),
        viewport: const Size(390, 844),
        overrides: [
          studentDashboardProvider.overrideWith(
            (ref) => StressFixtures.emptyStudentDashboard(),
          ),
        ],
      );
      expect(find.text('No homework due soon.'), findsOneWidget);
      expect(find.text('No periods scheduled today.'), findsOneWidget);
    });
  });

  group('Phase 4 — error states', () {
    testWidgets('Parent dashboard shows error with retry', (tester) async {
      await pumpStressScreen(
        tester,
        screen: const ParentDashboardScreen(),
        viewport: const Size(390, 844),
        overrides: [
          parentDashboardErrorProvider.overrideWith((ref) => true),
        ],
      );
      expect(find.text('Unable to load dashboard right now.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('Teacher dashboard shows error with retry', (tester) async {
      await pumpStressScreen(
        tester,
        screen: const TeacherDashboardScreen(),
        viewport: const Size(390, 844),
        overrides: [
          teacherDashboardErrorProvider.overrideWith((ref) => true),
        ],
      );
      expect(find.text('Unable to load dashboard right now.'), findsOneWidget);
    });
  });

  group('Phase 6 — accessibility text scale', () {
    for (final scale in StressFixtures.textScales) {
      testWidgets('Parent dashboard text scale $scale', (tester) async {
        await pumpStressScreen(
          tester,
          screen: const ParentDashboardScreen(),
          viewport: const Size(390, 844),
          textScale: scale,
          overrides: [
            parentDashboardProvider.overrideWith(
              (ref) => StressFixtures.stressParentDashboard(),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Phase 1 ERP dashboards — responsive', () {
    final erpScreens = <Widget>[
      const ManagementDashboardScreen(),
      const FinanceDashboardScreen(),
      const InventoryDashboardScreen(),
      const IntelligenceHubScreen(),
    ];

    for (final viewport in [
      const Size(390, 844),
      const Size(834, 1194),
    ]) {
      for (final screen in erpScreens) {
        testWidgets('${screen.runtimeType} ${viewport.width}x${viewport.height}', (
          tester,
        ) async {
          await pumpGoldenErpScreen(
            tester,
            screen: screen,
            viewport: viewport,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
