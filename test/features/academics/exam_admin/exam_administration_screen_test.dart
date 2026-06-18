import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_admin_models.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_administration_screen.dart';
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

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        sharedPreferencesTestOverride(testPrefs),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(ErpRole.principal),
        ),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const ExamAdministrationScreen(),
      ),
    );
  }

  group('ExamAdministrationScreen', () {
    testWidgets('renders seeded exams and lifecycle actions', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Exam Administration'), findsOneWidget);
      expect(find.text('Unit Test — Mathematics'), findsOneWidget);
      expect(find.text('Unit Test — Science'), findsOneWidget);
      expect(find.byKey(QaTestKeys.examAdminCreateButton), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.examAdminOpenMarksButton('exam_science_8a')),
        findsOneWidget,
      );
    });

    testWidgets('phase filter chips update visible exams', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final scheduledChip = find.widgetWithText(FilterChip, 'Scheduled');
      await tester.ensureVisible(scheduledChip);
      await tester.tap(scheduledChip);
      await tester.pumpAndSettle();

      expect(find.text('Unit Test — Science'), findsOneWidget);
      expect(find.text('Unit Test — Mathematics'), findsNothing);
    });
  });

  // Slice 4 — approve + publish surfaced on the workspace hub.
  group('ExamAdministrationScreen approval status surfacing', () {
    ExamAdministrationStore store() => ExamAdministrationStore.instance;

    void process(String examId) {
      for (final mark in store().marksForExam(examId)) {
        if (mark.marksObtained == null) {
          store().recordMark(markEntryId: mark.id, marksObtained: 38);
        }
      }
      store().processResults(examId);
    }

    final statusChipKey =
        QaTestKeys.examAdminApprovalStatusChip('exam_math_8a');

    testWidgets('no approval chip while marks are still in progress',
        (tester) async {
      // exam_math_8a seeds in marks-entry, exam_science_8a in scheduled —
      // neither should surface an approval-chain status yet.
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(statusChipKey), findsNothing);
    });

    testWidgets('processed exam awaits coordinator verification',
        (tester) async {
      process('exam_math_8a');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(statusChipKey), findsOneWidget);
      expect(find.text('Awaiting coordinator verification'), findsOneWidget);
    });

    testWidgets('verified exam awaits principal approval', (tester) async {
      process('exam_math_8a');
      store().markCoordinatorVerified('exam_math_8a', verifiedBy: 'Coordinator');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(statusChipKey), findsOneWidget);
      expect(find.text('Awaiting principal approval'), findsOneWidget);
    });

    testWidgets('returned exam shows principal feedback', (tester) async {
      process('exam_math_8a');
      store().recordRejectionComment('exam_math_8a', 'Recheck absent codes.');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(statusChipKey), findsOneWidget);
      expect(find.text('Returned by principal'), findsOneWidget);
      expect(
        find.text('Principal feedback: Recheck absent codes.'),
        findsOneWidget,
      );
    });

    testWidgets('published exam shows live status', (tester) async {
      process('exam_math_8a');
      store().publishExamResults('exam_math_8a');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(statusChipKey), findsOneWidget);
      expect(find.text('Published to students & parents'), findsOneWidget);
    });
  });

  group('examApprovalStatus', () {
    ExamSession session(
      ExamLifecyclePhase phase, {
      bool verified = false,
      String? rejection,
    }) =>
        ExamSession(
          id: 'exam_x',
          title: 'Unit Test',
          subject: 'Mathematics',
          grade: '8',
          section: 'A',
          termLabel: 'Term 2',
          dateLabel: '12 Jun 2026',
          timeLabel: '9:00 AM',
          venueLabel: 'Room 8A',
          syllabusLabel: 'Algebra',
          maxMarks: 50,
          phase: phase,
          coordinatorVerified: verified,
          rejectionComment: rejection,
        );

    test('draft and scheduled have nothing to approve', () {
      expect(
        examApprovalStatus(session(ExamLifecyclePhase.draft)),
        ExamApprovalStatus.none,
      );
      expect(
        examApprovalStatus(session(ExamLifecyclePhase.scheduled)),
        ExamApprovalStatus.none,
      );
    });

    test('marks entry maps to marks in progress', () {
      expect(
        examApprovalStatus(session(ExamLifecyclePhase.marksEntry)),
        ExamApprovalStatus.marksInProgress,
      );
    });

    test('processed but unverified awaits coordinator verification', () {
      expect(
        examApprovalStatus(session(ExamLifecyclePhase.processed)),
        ExamApprovalStatus.awaitingVerification,
      );
    });

    test('processed and verified awaits principal approval', () {
      expect(
        examApprovalStatus(
          session(ExamLifecyclePhase.processed, verified: true),
        ),
        ExamApprovalStatus.awaitingApproval,
      );
    });

    test('published maps to published', () {
      expect(
        examApprovalStatus(session(ExamLifecyclePhase.published)),
        ExamApprovalStatus.published,
      );
    });

    test('a rejection comment overrides the processed phase as returned', () {
      expect(
        examApprovalStatus(
          session(
            ExamLifecyclePhase.processed,
            verified: true,
            rejection: 'Recheck roll 06.',
          ),
        ),
        ExamApprovalStatus.returned,
      );
    });

    test('publish takes precedence over a lingering rejection comment', () {
      expect(
        examApprovalStatus(
          session(ExamLifecyclePhase.published, rejection: 'old note'),
        ),
        ExamApprovalStatus.published,
      );
    });

    test('every status except none has a label', () {
      for (final status in ExamApprovalStatus.values) {
        final label = examApprovalStatusLabel(status);
        if (status == ExamApprovalStatus.none) {
          expect(label, isEmpty);
        } else {
          expect(label, isNotEmpty);
        }
      }
    });
  });
}
