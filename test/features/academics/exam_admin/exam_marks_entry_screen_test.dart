import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/exams/exam_remark.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_marks_entry_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/exam_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;

  setUp(() async {
    testPrefs = await resetExamAdministrationForTest();
  });

  Widget buildTestApp({ErpRole role = ErpRole.principal}) {
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
        home: const ExamMarksEntryScreen(examId: 'exam_math_8a'),
      ),
    );
  }

  group('ExamMarksEntryScreen', () {
    testWidgets('renders marks roster and process action', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Unit Test — Mathematics'), findsOneWidget);
      expect(find.text('8-A · Mathematics'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.examAdminProcessResultsButton('exam_math_8a')),
        findsOneWidget,
      );
    });

    testWidgets('principal can author a leadership remark per student',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Each student row exposes the leadership remark button to the principal.
      final remarkButtons = find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            w.key.toString().contains('exam_leadership_remark_'),
      );
      expect(remarkButtons, findsWidgets);

      await tester.tap(remarkButtons.first);
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.examLeadershipRemarkField), findsOneWidget);
      await tester.enterText(
        find.byKey(QaTestKeys.examLeadershipRemarkField),
        'Excellent term — keep it up.',
      );
      await tester.tap(find.byKey(QaTestKeys.examLeadershipRemarkSaveButton));
      await tester.pumpAndSettle();

      // The remark persisted in the leadership slot for some seeded student.
      final store = ExamAdministrationStore.instance;
      final saved = store
          .remarksForExam('exam_math_8a')
          .where((r) => r.authorRole == ExamRemarkAuthorRole.principal)
          .toList();
      expect(saved, hasLength(1));
      expect(saved.first.text, 'Excellent term — keep it up.');
    });

    testWidgets(
        'EXM-D6: marking a student Absent (AB) via the status selector clears '
        'marks and persists the status', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final store = ExamAdministrationStore.instance;
      const markId = 'exam_math_8a_01';
      // Seeded present with marks.
      expect(store.markById(markId)!.status, ExamMarkStatus.present);
      expect(store.markById(markId)!.marksObtained, 42);

      // Open the per-row status selector and pick "Absent (AB)".
      await tester.tap(
        find.byKey(QaTestKeys.examAdminMarkStatusSelector(markId)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ExamMarkStatus.absent.label).last);
      await tester.pumpAndSettle();

      final updated = store.markById(markId)!;
      expect(updated.status, ExamMarkStatus.absent);
      expect(updated.marksObtained, isNull); // marks cleared for an absent student
      expect(updated.statusCode, 'AB');
      // The locked cell shows the AB display code instead of a marks field.
      expect(find.byKey(QaTestKeys.examAdminMarkField(markId)), findsNothing);
      expect(find.text('AB'), findsWidgets);
    });

    testWidgets('non-leadership staff do not see the remark button',
        (tester) async {
      await tester.pumpWidget(buildTestApp(role: ErpRole.teacher));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              w.key.toString().contains('exam_leadership_remark_'),
        ),
        findsNothing,
      );
    });
  });
}
