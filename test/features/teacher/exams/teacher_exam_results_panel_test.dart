import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/exam_test_helpers.dart';

/// Slice 4 — exercises the teacher Results panel approve/publish flow, which
/// drives the submit-for-verification / submit-for-approval UI. Approval is
/// required by default (EXAM_APPROVAL_REQUIRED), so the gated buttons show.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const examId = 'exam_math_8a';
  late SharedPreferences testPrefs;
  late ExamAdministrationStore store;

  setUp(() async {
    testPrefs = await resetExamAdministrationForTest();
    store = ExamAdministrationStore.instance;
  });

  Widget buildTeacherExams() {
    return ProviderScope(
      overrides: [
        sharedPreferencesTestOverride(testPrefs),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(ErpRole.teacher),
        ),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const TeacherExamsScreen(),
      ),
    );
  }

  void process(String id) {
    for (final mark in store.marksForExam(id)) {
      if (mark.marksObtained == null) {
        store.recordMark(markEntryId: mark.id, marksObtained: 38);
      }
    }
    store.processResults(id);
  }

  Future<void> openResults(WidgetTester tester) async {
    await tester.pumpWidget(buildTeacherExams());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
  }

  testWidgets('marks-entry exam offers submit for coordinator verification',
      (tester) async {
    await openResults(tester);

    expect(
      find.byKey(QaTestKeys.examSubmitVerificationButton),
      findsOneWidget,
    );
    expect(find.text('Submit for verification'), findsOneWidget);
    expect(find.byKey(QaTestKeys.examSubmitApprovalButton), findsNothing);
  });

  testWidgets('processed-but-unverified exam waits on the coordinator',
      (tester) async {
    process(examId);

    await openResults(tester);

    expect(
      find.text(
        'Awaiting exam coordinator verification before principal approval.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(QaTestKeys.examSubmitApprovalButton), findsNothing);
  });

  testWidgets('verified exam offers submit for principal approval',
      (tester) async {
    process(examId);
    store.markCoordinatorVerified(examId, verifiedBy: 'Coordinator');

    await openResults(tester);

    expect(find.byKey(QaTestKeys.examSubmitApprovalButton), findsOneWidget);
    expect(find.text('Submit for principal approval'), findsOneWidget);
  });

  testWidgets('a returned exam shows the principal feedback to the teacher',
      (tester) async {
    store.recordRejectionComment(examId, 'Recheck absent codes for roll 06.');

    await openResults(tester);

    expect(
      find.text('Principal feedback: Recheck absent codes for roll 06.'),
      findsOneWidget,
    );
  });
}
