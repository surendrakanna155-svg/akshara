import 'package:akshara_erp/features/admissions/documents/admissions_documents_provider.dart';
import 'package:akshara_erp/features/admissions/documents/admissions_documents_screen.dart';
import 'package:akshara_erp/features/admissions/enrollment/admissions_enrollment_screen.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_lead_detail_provider.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_lead_detail_screen.dart';
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

Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
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
  group('Admissions Phase 2 screens', () {
    testWidgets('AdmissionsLeadDetailScreen renders profile and timeline', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const AdmissionsLeadDetailScreen(leadId: 'LD-1042'),
      );

      expect(find.text('Ananya Reddy'), findsWidgets);
      expect(find.text('Activity timeline'), findsOneWidget);
      expect(find.text('Follow-up history'), findsOneWidget);
      expect(find.text('Status progression'), findsOneWidget);
    });

    testWidgets('AdmissionsLeadDetailScreen shows loading state', (
      tester,
    ) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            admissionsLeadDetailLoadingProvider('LD-1042')
                .overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const AdmissionsLeadDetailScreen(leadId: 'LD-1042'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('AdmissionsEnrollmentScreen renders wizard steps', (
      tester,
    ) async {
      await pumpScreen(tester, const AdmissionsEnrollmentScreen());

      expect(find.text('Student profile'), findsWidgets);
      expect(find.text('Student full name *'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('AdmissionsEnrollmentScreen advances to parent step', (
      tester,
    ) async {
      await pumpScreen(tester, const AdmissionsEnrollmentScreen());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ravi Kumar');
      await tester.enterText(fields.at(1), '01 Jan 2012');
      await tester.enterText(fields.at(2), 'Male');
      await tester.enterText(fields.at(3), '123456789012');

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Parent / guardian'), findsOneWidget);
      expect(find.text('Guardian name *'), findsOneWidget);
    });

    testWidgets('AdmissionsDocumentsScreen renders KPIs and checklist', (
      tester,
    ) async {
      await pumpScreen(tester, const AdmissionsDocumentsScreen());

      expect(find.text('Pending'), findsAtLeastNWidgets(1));
      expect(find.text('Missing'), findsAtLeastNWidgets(1));
      expect(find.text('Verification checklist'), findsOneWidget);
      expect(find.text('Birth Certificate'), findsWidgets);
    });

    testWidgets('AdmissionsDocumentsScreen shows error state', (tester) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            admissionsDocumentsErrorProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const AdmissionsDocumentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
