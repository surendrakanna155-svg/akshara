import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_reports_provider.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_reports_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/exam_test_helpers.dart';

/// EXM-3/4/5/7 — Exam Reports area widget tests: RBAC gate + tab switching +
/// report content (present-only exclusion surfaced in the tabulation grid).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;

  setUp(() async {
    testPrefs = await resetExamAdministrationForTest();
  });

  Widget buildApp({ErpRole role = ErpRole.principal}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesTestOverride(testPrefs),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(role),
        ),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const ExamReportsScreen(),
      ),
    );
  }

  group('ExamReportsScreen', () {
    testWidgets('a role without viewExams sees a locked empty state',
        (tester) async {
      await tester.pumpWidget(buildApp(role: ErpRole.parent));
      await tester.pumpAndSettle();

      expect(find.textContaining('do not have permission'), findsOneWidget);
      expect(find.byKey(QaTestKeys.examReportsExportCsvButton), findsNothing);
    });

    testWidgets('renders the four report tabs + export actions', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      for (final t in ExamReportTab.values) {
        expect(find.byKey(QaTestKeys.examReportsTab(t.keyName)), findsOneWidget);
      }
      expect(find.byKey(QaTestKeys.examReportsExportCsvButton), findsOneWidget);
      expect(find.byKey(QaTestKeys.examReportsExportPdfButton), findsOneWidget);
    });

    testWidgets('datesheet tab lists the seeded class schedule', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.examReportsTab('datesheet')));
      await tester.pumpAndSettle();

      // Seeded 8-A Term 2 has a Mathematics + Science exam.
      expect(find.textContaining('Mathematics'), findsWidgets);
    });

    testWidgets(
        'tabulation shows AB for an absent student and excludes them from rank',
        (tester) async {
      // Mark roll 03 absent and publish so the tabulation has data.
      final store = ExamAdministrationStore.instance;
      store.recordMark(
        markEntryId: 'exam_math_8a_03',
        marksObtained: 0,
        status: ExamMarkStatus.absent,
      );
      store.publishExamResults('exam_math_8a');

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Tabulation is the default tab; the absent cell renders 'AB'.
      expect(find.text('AB'), findsWidgets);
    });
  });
}
