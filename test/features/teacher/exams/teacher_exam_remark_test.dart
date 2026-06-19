import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/teaching/teacher_assignment_registry.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/communication/teacher_teaching_context_provider.dart';
import 'package:akshara_erp/features/teacher/exams/exam_models.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/exam_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ravi = 'SIS-STU-10430'; // roll 01, 8-A
  late SharedPreferences testPrefs;
  late ExamAdministrationStore store;

  setUp(() async {
    testPrefs = await resetExamAdministrationForTest();
    store = ExamAdministrationStore.instance;
  });

  Widget buildScreen(String teacherId, String teacherName) {
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
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const TeacherExamsScreen(),
      ),
    );
  }

  Future<void> openMarksEntry(WidgetTester tester) async {
    await tester.pumpWidget(buildScreen(
      TeacherAssignmentRegistry.priyaSharmaId,
      'Priya Sharma',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marks entry'));
    await tester.pumpAndSettle();
  }

  testWidgets('class teacher can write and save a student remark',
      (tester) async {
    await openMarksEntry(tester);

    final remarkBtn =
        find.byKey(QaTestKeys.teacherExamRemarkButton('exam_math_8a_01'));
    expect(remarkBtn, findsOneWidget);

    await tester.ensureVisible(remarkBtn);
    await tester.tap(remarkBtn);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(QaTestKeys.teacherExamRemarkField),
      'Excellent problem-solving this term.',
    );
    await tester.tap(find.byKey(QaTestKeys.teacherExamRemarkSaveButton));
    await tester.pumpAndSettle();

    final saved = store.remarkFor('exam_math_8a', ravi);
    expect(saved, isNotNull);
    expect(saved!.text, 'Excellent problem-solving this term.');
    expect(saved.authorName, 'Priya Sharma');
    expect(saved.history, hasLength(1));
  });

  testWidgets('subject teacher who is not the class teacher sees no remark button',
      (tester) async {
    // Mr. Patel teaches Science but is not a class teacher; give him a Science
    // 8-A exam in marks entry so the marks list renders.
    final science = store.createExam(
      title: 'Unit Test — Science',
      subject: 'Science',
      grade: '8',
      section: 'A',
      termLabel: 'Term 2',
      dateLabel: '24 Jun 2026',
      timeLabel: '11:00 AM',
      venueLabel: 'Lab 2',
      syllabusLabel: 'Cells',
      maxMarks: 50,
    );
    store.scheduleExam(science.id);
    store.openMarksEntry(science.id);

    await tester.pumpWidget(buildScreen(
      TeacherAssignmentRegistry.mrPatelId,
      'Mr. Patel',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marks entry'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(QaTestKeys.teacherExamRemarkButton('${science.id}_01')),
      findsNothing,
    );
  });
}
