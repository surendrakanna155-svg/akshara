import 'package:akshara_erp/core/config/exam_approval_config.dart';
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

  Widget buildTestApp({
    ErpRole role = ErpRole.principal,
    bool approvalRequired = true,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesTestOverride(testPrefs),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(role),
        ),
        // UXR-D5 — the direct "Publish results" button only appears when
        // principal approval is NOT required; override so the direct-publish
        // confirmation path is exercisable.
        examApprovalRequiredProvider.overrideWithValue(approvalRequired),
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

    // EXM-1 — fast bulk marks entry: the grid Save-all path.
    testWidgets('EXM-1: Save all persists changed marks in one batch',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final store = ExamAdministrationStore.instance;
      // The seeded exam leaves roll 06 (mark id exam_math_8a_06) unentered.
      const openMarkId = 'exam_math_8a_06';
      expect(store.markById(openMarkId)!.marksObtained, isNull);

      // Scroll the open row's field into view (it is below the fold), then type
      // a new mark into it.
      final openField = find.byKey(QaTestKeys.examAdminMarkField(openMarkId));
      await tester.scrollUntilVisible(
        openField,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(openField, '37');
      await tester.pumpAndSettle();

      // Press "Save all".
      final saveAll = find.byKey(QaTestKeys.examAdminMarksSaveAllButton);
      expect(saveAll, findsOneWidget);
      await tester.ensureVisible(saveAll);
      await tester.tap(saveAll);
      await tester.pumpAndSettle();

      // The batch persisted the changed row and reported the outcome.
      expect(store.markById(openMarkId)!.marksObtained, 37);
      expect(find.textContaining('saved'), findsWidgets);
    });

    testWidgets('EXM-1: Enter on a marks field advances focus to the next row',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final firstField = find.byKey(
        QaTestKeys.examAdminMarkField('exam_math_8a_01'),
      );
      await tester.enterText(firstField, '41');
      // Submit (Enter) — the row saves and focus moves on without throwing.
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      expect(
        ExamAdministrationStore.instance
            .markById('exam_math_8a_01')!
            .marksObtained,
        41,
      );
    });

    // UXR-D5 — publishing results to parents (the most consequential Exams
    // action) must show a summary confirmation, not fire on a single tap.
    testWidgets(
        'UXR-D5: "Publish results" shows a summary confirmation (N/M/K); '
        'Cancel does not publish, Confirm does', (tester) async {
      // approvalRequired:false surfaces the direct-publish button.
      await tester.pumpWidget(buildTestApp(approvalRequired: false));
      await tester.pumpAndSettle();

      final store = ExamAdministrationStore.instance;
      // Seeded 8-A roster: 5 students, all Present, roll 06 has no mark entered.
      //   N (total)    = 5
      //   M (absent)   = 0  (none carry AB/ML/DB)
      //   K (unmarked) = 1  (roll 06 is Present with a null mark)
      expect(
        store.examById('exam_math_8a')!.phase,
        ExamLifecyclePhase.marksEntry,
      );
      expect(store.marksForExam('exam_math_8a'), hasLength(5));
      expect(store.markById('exam_math_8a_06')!.marksObtained, isNull);

      final publishButton =
          find.byKey(QaTestKeys.examAdminPublishResultsButton);
      await tester.ensureVisible(publishButton);
      await tester.tap(publishButton);
      await tester.pumpAndSettle();

      // A confirmation dialog appears — no immediate publish on the first tap.
      final dialog = find.byKey(QaTestKeys.examAdminPublishConfirmDialog);
      expect(dialog, findsOneWidget);
      expect(find.textContaining('Published'), findsNothing);

      // Summary reflects the REAL roster: class · subject, N=5, M=0 absent,
      // and K=1 unmarked surfaced prominently as a warning.
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('8-A · Mathematics'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.textContaining('Absent')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('0')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('1 student has no marks entered'),
        ),
        findsOneWidget,
      );

      // Cancel = no-op: dialog closes and nothing is published.
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(TextButton, 'Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(QaTestKeys.examAdminPublishConfirmDialog),
        findsNothing,
      );
      expect(
        store.examById('exam_math_8a')!.phase,
        ExamLifecyclePhase.marksEntry,
      );
      expect(find.textContaining('Published'), findsNothing);

      // Re-open, Confirm = the existing publish runs and keeps the snackbar.
      await tester.tap(publishButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(QaTestKeys.examAdminPublishConfirmButton));
      await tester.pumpAndSettle();

      expect(
        store.examById('exam_math_8a')!.phase,
        ExamLifecyclePhase.published,
      );
      expect(find.textContaining('Published'), findsWidgets);
    });
  });
}
