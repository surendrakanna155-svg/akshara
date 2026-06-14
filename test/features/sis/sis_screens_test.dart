import 'package:akshara_erp/features/sis/academic_assignment/sis_academic_assignment_screen.dart';
import 'package:akshara_erp/features/sis/admissions_conversion/sis_admissions_conversion_screen.dart';
import 'package:akshara_erp/features/sis/dashboard/sis_dashboard_provider.dart';
import 'package:akshara_erp/features/sis/dashboard/sis_dashboard_screen.dart';
import 'package:akshara_erp/features/sis/profile/sis_profile_screen.dart';
import 'package:akshara_erp/features/sis/registry/sis_registry_provider.dart';
import 'package:akshara_erp/features/sis/registry/sis_registry_screen.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_helpers.dart';

void useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pumpSisScreen(WidgetTester tester, Widget screen) async {
  useDesktopViewport(tester);
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
  group('SIS module screens', () {
    testWidgets('SisDashboardScreen renders KPIs and distributions', (
      tester,
    ) async {
      await pumpSisScreen(tester, const SisDashboardScreen());

      expect(find.text('Total Students'), findsOneWidget);
      expect(find.text('1,248'), findsOneWidget);
      expect(find.text('Class distribution'), findsOneWidget);
      expect(find.text('Recent enrollments'), findsOneWidget);
      expect(find.textContaining('pending admissions conversions'),
          findsOneWidget);
    });

    testWidgets('SisDashboardScreen shows loading state', (tester) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            sisDashboardLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const SisDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('SisRegistryScreen renders student list', (tester) async {
      await pumpSisScreen(tester, const SisRegistryScreen());

      expect(find.text('Arjun Patel'), findsWidgets);
      expect(find.text('Export'), findsOneWidget);
    });

    testWidgets('SisRegistryScreen shows empty state', (tester) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            sisRegistryEmptyProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const SisRegistryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('SisStudentProfileScreen renders profile sections', (
      tester,
    ) async {
      await pumpSisScreen(
        tester,
        const SisStudentProfileScreen(studentId: 'SIS-STU-10421'),
      );

      expect(find.text('Arjun Patel'), findsWidgets);
      expect(find.text('Parent details'), findsOneWidget);
      expect(find.text('Fee account summary'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.byKey(QaTestKeys.sisEditProfileButton), findsOneWidget);
      expect(find.byKey(QaTestKeys.sisUploadDocumentButton), findsOneWidget);
    });

    testWidgets('SisAcademicAssignmentScreen renders assignment form', (
      tester,
    ) async {
      await pumpSisScreen(tester, const SisAcademicAssignmentScreen());

      expect(find.text('Academic assignment'), findsOneWidget);
      expect(find.text('Save assignment'), findsOneWidget);
      expect(find.text('Bulk assignment template'), findsOneWidget);
    });

    testWidgets('SisAdmissionsConversionScreen renders conversion queue', (
      tester,
    ) async {
      await pumpSisScreen(tester, const SisAdmissionsConversionScreen());

      expect(find.text('Admissions conversion'), findsOneWidget);
      expect(find.text('Convert to SIS student'), findsOneWidget);
      expect(find.text('Ananya Reddy'), findsWidgets);
    });
  });
}
