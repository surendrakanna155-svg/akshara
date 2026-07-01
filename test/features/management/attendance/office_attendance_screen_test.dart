import 'package:akshara_erp/core/repositories/mock/mock_attendance_office_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/management/attendance/office_attendance_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap() {
  return ProviderScope(
    overrides: [
      attendanceOfficeRepositoryProvider
          .overrideWithValue(const MockAttendanceOfficeRepository()),
      repositoryQueryProvider.overrideWith((ref) => RepositoryQuery.demo),
    ],
    child: MaterialApp(
      theme: AksharaAppTheme.light(),
      home: const OfficeAttendanceScreen(),
    ),
  );
}

void main() {
  group('Office attendance screen (ATT-1/2/4/D1/D2)', () {
    testWidgets('renders the 4 tabs and the register list by default',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Office attendance'), findsOneWidget);
      // Tabs exist (keyed).
      expect(find.byKey(QaTestKeys.officeAttendanceTab('Register')),
          findsOneWidget);
      expect(find.byKey(QaTestKeys.officeAttendanceTab('Monthly')),
          findsOneWidget);
      expect(find.byKey(QaTestKeys.officeAttendanceTab('Pending')),
          findsOneWidget);
      expect(
          find.byKey(QaTestKeys.officeAttendanceTab('Alerts')), findsOneWidget);

      // Register tab is active and shows a student from the mock feed.
      expect(find.textContaining('Arjun Patel'), findsOneWidget);
      // Export buttons are present on the register tab.
      expect(find.byKey(QaTestKeys.officeAttendanceExportCsvButton),
          findsOneWidget);
      expect(find.byKey(QaTestKeys.officeAttendanceExportPdfButton),
          findsOneWidget);
    });

    testWidgets('pending tab lists classes that have not submitted',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.officeAttendanceTab('Pending')));
      await tester.pumpAndSettle();

      // Mock pending feed has a draft (9-A) and a missing (10-A).
      expect(find.textContaining('Class 9-A'), findsOneWidget);
      expect(find.text('Draft'), findsWidgets);
    });

    testWidgets('alerts tab shows consecutive-absence + short-attendance',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.officeAttendanceTab('Alerts')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Consecutive absence'), findsOneWidget);
      expect(find.textContaining('Short attendance'), findsOneWidget);
      // A flagged student appears in both sections.
      expect(find.textContaining('Chetan Kumar'), findsWidgets);
      // Threshold + days controls are present.
      expect(find.byKey(QaTestKeys.officeAttendanceThresholdField),
          findsOneWidget);
      expect(find.byKey(QaTestKeys.officeAttendanceConsecutiveDaysField),
          findsOneWidget);
    });
  });
}
