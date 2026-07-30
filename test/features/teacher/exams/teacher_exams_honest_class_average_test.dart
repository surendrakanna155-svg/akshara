import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/teaching/teacher_assignment_registry.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/teacher/communication/teacher_teaching_context_provider.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_provider.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/exam_test_helpers.dart';

/// RC honest-state + no-fabricated-data certification for TA-05 Exams.
///
/// Two claims the screen used to make that the data did not support:
///
///  1. The class-average ring rendered a filled `0%` before ANY mark existed —
///     asserting a MEASURED average of zero. Unknown must read as unknown.
///  2. The Results insight card hardcoded `'… for Unit Test — Mathematics.'`, so
///     every teacher of every subject was told their exam was Maths.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late ExamAdministrationStore store;

  setUp(() async {
    testPrefs = await resetExamAdministrationForTest();
    store = ExamAdministrationStore.instance;
  });

  Widget buildScreen({
    required String teacherId,
    required String teacherName,
    String? selectedExamId,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesTestOverride(testPrefs),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(ErpRole.teacher),
        ),
        teacherTeachingContextOverrideProvider.overrideWith(
          (ref) => TeacherAssignmentRegistry.resolveContext(
            teacherId: teacherId,
            teacherName: teacherName,
          ),
        ),
        if (selectedExamId != null)
          teacherSelectedExamIdProvider.overrideWith((ref) => selectedExamId),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const TeacherExamsScreen(),
      ),
    );
  }

  /// A brand-new marks-entry session for [teacher]'s class with a provisioned
  /// roster and NOT ONE mark recorded — the "nothing measured yet" state.
  String freshUnscoredExam({
    required String title,
    required String subject,
    required String grade,
    required String section,
  }) {
    final exam = store.createExam(
      title: title,
      subject: subject,
      grade: grade,
      section: section,
      termLabel: 'Term 2',
      dateLabel: '30 Jun 2026',
      timeLabel: '9:00 AM',
      venueLabel: 'Room $grade$section',
      syllabusLabel: 'Mensuration',
      maxMarks: 50,
    );
    store.scheduleExam(exam.id);
    store.openMarksEntry(exam.id);
    return exam.id;
  }

  group('honest class average — nothing entered is NOT a measured 0%', () {
    testWidgets('the summary ring reads unknown, never "0%"', (tester) async {
      final examId = freshUnscoredExam(
        title: 'Midterm — Mathematics',
        subject: 'Mathematics',
        grade: '8',
        section: 'A',
      );

      await tester.pumpWidget(buildScreen(
        teacherId: TeacherAssignmentRegistry.priyaSharmaId,
        teacherName: 'Priya Sharma',
        selectedExamId: examId,
      ));
      await tester.pumpAndSettle();

      // The ring's caption still identifies the metric …
      expect(find.text('Class avg'), findsOneWidget);
      // … but the value is the app's standard unknown placeholder, NOT a
      // fabricated measured zero.
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
    });

    testWidgets('the provider exposes null (not 0) when nothing is scored',
        (tester) async {
      final examId = freshUnscoredExam(
        title: 'Midterm — Mathematics',
        subject: 'Mathematics',
        grade: '8',
        section: 'A',
      );

      await tester.pumpWidget(buildScreen(
        teacherId: TeacherAssignmentRegistry.priyaSharmaId,
        teacherName: 'Priya Sharma',
        selectedExamId: examId,
      ));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TeacherExamsScreen)),
      );
      expect(container.read(teacherClassAveragePercentProvider), isNull);
    });

    testWidgets('the Results insight claims no average it cannot support',
        (tester) async {
      final examId = freshUnscoredExam(
        title: 'Midterm — Mathematics',
        subject: 'Mathematics',
        grade: '8',
        section: 'A',
      );

      await tester.pumpWidget(buildScreen(
        teacherId: TeacherAssignmentRegistry.priyaSharmaId,
        teacherName: 'Priya Sharma',
        selectedExamId: examId,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Results'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No marks have been entered yet for Midterm — Mathematics, so there '
          'is no class average to show.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Class average is 0%'), findsNothing);
    });
  });

  group('Results insight names the REAL exam, never a hardcoded one', () {
    testWidgets('a science teacher is told about their science exam',
        (tester) async {
      // Mr. Patel teaches Science 8-A — he must never be told "Mathematics".
      final examId = freshUnscoredExam(
        title: 'Unit Test — Science',
        subject: 'Science',
        grade: '8',
        section: 'A',
      );
      for (final mark in store.marksForExam(examId)) {
        store.recordMark(markEntryId: mark.id, marksObtained: 40);
      }

      await tester.pumpWidget(buildScreen(
        teacherId: TeacherAssignmentRegistry.mrPatelId,
        teacherName: 'Mr. Patel',
        selectedExamId: examId,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Results'));
      await tester.pumpAndSettle();

      expect(
        find.text('Class average is 80% for Unit Test — Science.'),
        findsOneWidget,
      );
      expect(find.textContaining('Mathematics'), findsNothing);
    });

    testWidgets('a maths teacher is told about their own maths session',
        (tester) async {
      // The seeded 8-A maths session ("Unit Test — Mathematics", 50 max) has
      // every roll but 06 pre-entered — a real, measurable average.
      await tester.pumpWidget(buildScreen(
        teacherId: TeacherAssignmentRegistry.priyaSharmaId,
        teacherName: 'Priya Sharma',
        selectedExamId: 'exam_math_8a',
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Results'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('for Unit Test — Mathematics.'),
        findsOneWidget,
      );
      expect(find.textContaining('Class average is'), findsOneWidget);
      // The exam name is derived, so it is NOT the subject appended twice.
      expect(
        find.textContaining('Unit Test — Mathematics — Mathematics'),
        findsNothing,
      );
    });
  });
}
