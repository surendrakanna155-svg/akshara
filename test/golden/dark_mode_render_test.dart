@TestOn('mac-os')
library;

import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/features/admin/screens/admin_hub_screen.dart';
import 'package:akshara_erp/features/finance/dashboard/finance_dashboard_screen.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_screen.dart';
import 'package:akshara_erp/features/settings/appearance_settings_screen.dart';
import 'package:akshara_erp/features/student/dashboard/student_dashboard_screen.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_test_helpers.dart';

/// Phase C.3/C.4 — render the key consumer screens in DARK theme to verify
/// surfaces/contrast adapt (no light-mode patches). Captured as dark goldens.
void main() {
  const viewport = GoldenViewports.mobile390;

  group('Dark-mode render', () {
    testWidgets('parent dashboard (dark)', (tester) async {
      await pumpGoldenDashboard(
        tester,
        screen: const ParentDashboardScreen(),
        viewport: viewport,
        dark: true,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(goldenFileName('dark_parent_dashboard', '390x844')),
      );
    });

    testWidgets('student dashboard (dark)', (tester) async {
      await pumpGoldenDashboard(
        tester,
        screen: const StudentDashboardScreen(),
        viewport: viewport,
        dark: true,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(goldenFileName('dark_student_dashboard', '390x844')),
      );
    });

    testWidgets('teacher dashboard (dark)', (tester) async {
      await pumpGoldenDashboard(
        tester,
        screen: const TeacherDashboardScreen(),
        viewport: viewport,
        dark: true,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(goldenFileName('dark_teacher_dashboard', '390x844')),
      );
    });

    testWidgets('admin hub / workspace landing (dark)', (tester) async {
      await pumpGoldenErpScreen(
        tester,
        screen: const AdminHubScreen(),
        viewport: GoldenViewports.tablet834,
        dark: true,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(goldenFileName('dark_admin_hub', '834x1194')),
      );
    });

    testWidgets('finance dashboard (dark)', (tester) async {
      await pumpGoldenErpScreen(
        tester,
        screen: const FinanceDashboardScreen(),
        viewport: GoldenViewports.tablet834,
        dark: true,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(goldenFileName('dark_finance_dashboard', '834x1194')),
      );
    });

    testWidgets('appearance settings screen (dark)', (tester) async {
      useGoldenViewport(tester, viewport);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AksharaAppTheme.dark(),
            debugShowCheckedModeBanner: false,
            home: const AppearanceSettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(goldenFileName('dark_appearance_settings', '390x844')),
      );
    });
  });
}
