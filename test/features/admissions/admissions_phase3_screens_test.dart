import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/features/admissions/approval/admissions_approval_provider.dart';
import 'package:akshara_erp/features/admissions/approval/admissions_approval_screen.dart';
import 'package:akshara_erp/features/admissions/fee_handoff/admissions_fee_handoff_screen.dart';
import 'package:akshara_erp/features/admissions/reports/admissions_reports_screen.dart';
import 'package:akshara_erp/features/admissions/settings/admissions_settings_screen.dart';
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
  group('Admissions Phase 3 screens', () {
    testWidgets('AdmissionsApprovalScreen renders queue and review', (
      tester,
    ) async {
      await pumpScreen(tester, const AdmissionsApprovalScreen());

      expect(find.text('Ananya Reddy'), findsWidgets);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Counselor notes'), findsOneWidget);
    });

    testWidgets('AdmissionsApprovalScreen shows loading state', (tester) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            admissionsApprovalLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const AdmissionsApprovalScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('AdmissionsFeeHandoffScreen renders handoff panel', (
      tester,
    ) async {
      await pumpScreen(tester, const AdmissionsFeeHandoffScreen());

      expect(find.text('Arjun Patel'), findsWidgets);
      expect(find.text('Send to Finance'), findsOneWidget);
      expect(find.textContaining('SIS-STU-'), findsWidgets);
    });

    testWidgets('AdmissionsReportsScreen renders funnel report', (
      tester,
    ) async {
      await pumpScreen(tester, const AdmissionsReportsScreen());

      expect(find.text('Conversion funnel'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
    });

    testWidgets('AdmissionsSettingsScreen renders configuration', (
      tester,
    ) async {
      await pumpScreen(tester, const AdmissionsSettingsScreen());

      expect(find.text('Lead stages'), findsOneWidget);
      expect(find.text('Notification templates'), findsOneWidget);
      expect(find.text('Visit reminder'), findsOneWidget);
    });

    testWidgets('AdmissionsSettingsScreen saves updated settings', (
      tester,
    ) async {
      useDesktopViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            admissionsRepositoryProvider.overrideWithValue(
              MockAdmissionsRepository(),
            ),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const AdmissionsSettingsScreen(),
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      final switches = find.byType(SwitchListTile);
      expect(switches, findsWidgets);
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Admissions settings saved'), findsOneWidget);
    });
  });
}
