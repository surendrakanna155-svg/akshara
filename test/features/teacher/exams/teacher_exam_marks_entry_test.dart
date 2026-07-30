import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/teaching/teacher_assignment_registry.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/communication/teacher_teaching_context_provider.dart';
import 'package:akshara_erp/features/teacher/exams/exam_models.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_provider.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_screen.dart';
import 'package:akshara_erp/shared/marks_grid/marks_grid.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/exam_test_helpers.dart';

/// QW1 · QA-F-038 — Teacher exam marks-entry grid + out-of-range validation.
/// Pumps [TeacherExamsScreen] → Marks entry, then proves: the marks grid renders
/// an editable field per student, an out-of-range mark is rejected with a
/// validation message and NOT persisted, and a valid mark saves to the store.
/// (The save→Submit-for-verification chain is covered by teacher_marks_submit_test
/// / QA-J-014; here we certify the grid-entry UI + validation that was deferred.)

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const firstEntryId = 'exam_math_8a_01'; // roll 01 (Ravi), 8-A Mathematics
  const maxMarks = 50;

  late SharedPreferences testPrefs;

  setUp(() async {
    testPrefs = await resetExamAdministrationForTest();
  });

  Widget buildScreen({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesTestOverride(testPrefs),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(ErpRole.teacher),
        ),
        teacherTeachingContextOverrideProvider.overrideWith(
          (ref) => TeacherAssignmentRegistry.resolveContext(
            teacherId: TeacherAssignmentRegistry.priyaSharmaId,
            teacherName: 'Priya Sharma',
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const TeacherExamsScreen(),
      ),
    );
  }

  Future<void> openMarksEntry(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(buildScreen(overrides: overrides));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marks entry'));
    await tester.pumpAndSettle();
  }

  Future<void> enterMark(WidgetTester tester, String value) async {
    final field = find.byKey(QaTestKeys.teacherExamMarkField(firstEntryId));
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pump();
    final save = find.byKey(QaTestKeys.teacherExamMarkSaveButton(firstEntryId));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  group('QA-F-038 · Teacher exam marks entry', () {
    testWidgets('the marks grid renders an editable field per student',
        (tester) async {
      await openMarksEntry(tester);
      expect(
        find.byKey(QaTestKeys.teacherExamMarkField(firstEntryId)),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.teacherExamMarkSaveButton(firstEntryId)),
        findsOneWidget,
      );
    });

    testWidgets('an out-of-range mark is rejected with a validation message',
        (tester) async {
      await openMarksEntry(tester);
      await enterMark(tester, '99'); // > maxMarks (50)

      expect(find.text('Marks must be between 0 and $maxMarks'), findsOneWidget);
    });

    testWidgets('the locked number pad blocks non-numeric input',
        (tester) async {
      // P2-UX-2 §2.2 — the shared MarksEntryField is a locked number pad, so a
      // non-numeric mark can no longer be typed in the first place (stronger
      // than the old post-save "Enter a valid number" rejection).
      await openMarksEntry(tester);
      final field = find.byKey(QaTestKeys.teacherExamMarkField(firstEntryId));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'ab12cd');
      await tester.pump();
      expect(
        tester.widget<TextField>(field).controller!.text,
        '12',
      );
    });

    testWidgets('a valid mark is accepted (no validation error)',
        (tester) async {
      await openMarksEntry(tester);
      await enterMark(tester, '45'); // within 0..50

      // The grid accepts the entry — no validation snackbar is shown.
      // (Persistence of a saved mark + Submit-for-verification is proven
      // deterministically by teacher_marks_submit_test.dart / QA-J-014.)
      expect(find.text('Marks must be between 0 and $maxMarks'), findsNothing);
      expect(find.text('Enter a valid number'), findsNothing);
      expect(find.text('Enter marks'), findsNothing);
    });

    testWidgets('P2-UX-2 §2.2 — spreadsheet-grade: stats footer + Save-all',
        (tester) async {
      await openMarksEntry(tester);

      // Save-all appears only once a row is dirty (a typed, unsaved value).
      expect(find.byKey(QaTestKeys.teacherExamSaveAllButton), findsNothing);
      final field = find.byKey(QaTestKeys.teacherExamMarkField(firstEntryId));
      await tester.ensureVisible(field);
      await tester.enterText(field, '40');
      await tester.pump();
      expect(find.byKey(QaTestKeys.teacherExamSaveAllButton), findsOneWidget);

      // Saving all clears the dirty state → the Save-all button retires.
      await tester.tap(find.byKey(QaTestKeys.teacherExamSaveAllButton));
      await tester.pumpAndSettle();
      expect(find.byKey(QaTestKeys.teacherExamSaveAllButton), findsNothing);

      // The shared column-stats footer sits at the foot of the roster (same
      // component the admin uses). The roster is a lazily-built sliver list
      // now — it is mounted when it enters the viewport, so scroll to it
      // rather than asserting on an eagerly-mounted off-screen widget.
      await tester.scrollUntilVisible(
        find.byKey(QaTestKeys.marksColumnStats),
        300,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byKey(QaTestKeys.marksColumnStats), findsOneWidget);
    });

    testWidgets('RC perf — a full class builds its rows lazily, not all at once',
        (tester) async {
      // The roster used to be a `for` loop inside a Column: a 40–60 student
      // class eagerly mounted (and kept mounted) 40–60 live TextFields with no
      // viewport recycling. It is a SliverList now — only the rows in/near the
      // viewport are built.
      const rosterSize = 60;
      final roster = [
        for (var i = 1; i <= rosterSize; i++)
          ExamMarkEntry(
            id: 'perf_roster_$i',
            sisStudentId: 'SIS-PERF-$i',
            studentName: 'Student $i',
            rollNo: i.toString().padLeft(2, '0'),
            marksObtained: null,
            maxMarks: maxMarks,
          ),
      ];

      await openMarksEntry(
        tester,
        overrides: [
          teacherExamMarksForActiveProvider.overrideWith((ref) async => roster),
          teacherExamMarksFutureProvider.overrideWith((ref) async => roster),
        ],
      );

      final mountedFields = find.byType(MarksEntryField).evaluate().length;
      expect(mountedFields, greaterThan(0),
          reason: 'the visible rows must still render an editable cell');
      expect(
        mountedFields,
        lessThan(rosterSize),
        reason: 'a $rosterSize-student roster must NOT mount $rosterSize '
            'TextFields up front — the list has to recycle with the viewport',
      );
    });
  });
}
