import 'package:akshara_erp/features/admissions/applications/admissions_applications_provider.dart';
import 'package:akshara_erp/features/admissions/applications/admissions_applications_screen.dart';
import 'package:akshara_erp/features/admissions/dashboard/admissions_dashboard_provider.dart';
import 'package:akshara_erp/features/admissions/dashboard/admissions_dashboard_screen.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_leads_provider.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_leads_screen.dart';
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

Future<void> pumpAdmissionsScreen(WidgetTester tester, Widget screen) async {
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
  group('Admissions module screens', () {
    testWidgets('AdmissionsDashboardScreen renders KPIs and pipeline', (
      tester,
    ) async {
      await pumpAdmissionsScreen(
        tester,
        const AdmissionsDashboardScreen(),
      );

      expect(find.text('Total Leads (MTD)'), findsOneWidget);
      expect(find.text('248'), findsOneWidget);
      expect(find.text('Pipeline preview'), findsOneWidget);
      expect(find.text('Follow-ups due today'), findsOneWidget);
      expect(find.textContaining('Conversion drops'), findsOneWidget);
    });

    testWidgets('AdmissionsDashboardScreen shows loading state', (
      tester,
    ) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            admissionsDashboardLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const AdmissionsDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('AdmissionsLeadsScreen renders CRM banner and leads', (
      tester,
    ) async {
      await pumpAdmissionsScreen(tester, const AdmissionsLeadsScreen());

      expect(
        find.textContaining('CRM system of record'),
        findsOneWidget,
      );
      expect(find.text('LD-1042'), findsOneWidget);
      expect(find.text('Ananya Reddy'), findsWidgets);
    });

    testWidgets('AdmissionsLeadsScreen shows empty state', (tester) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            admissionsLeadsEmptyProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const AdmissionsLeadsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('AdmissionsApplicationsScreen renders workflow and table', (
      tester,
    ) async {
      await pumpAdmissionsScreen(
        tester,
        const AdmissionsApplicationsScreen(),
      );

      expect(find.text('Draft'), findsAtLeastNWidgets(1));
      expect(find.text('Under review'), findsAtLeastNWidgets(1));
      expect(find.text('APP-2208'), findsOneWidget);
      expect(find.text('Ananya Reddy'), findsWidgets);
    });

    testWidgets('AdmissionsApplicationsScreen shows error state', (
      tester,
    ) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            admissionsApplicationsErrorProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const AdmissionsApplicationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
