import 'package:akshara_erp/core/communication/parent_communication_governance.dart';
import 'package:akshara_erp/features/teacher/communication/teacher_teaching_context_provider.dart';
import 'package:akshara_erp/features/teacher/leave/leave_models.dart';
import 'package:akshara_erp/features/teacher/leave/teacher_leave_provider.dart';
import 'package:akshara_erp/features/teacher/leave/teacher_leave_screen.dart';
import 'package:akshara_erp/features/teacher/leave_approvals/teacher_leave_approvals_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';
import '../../../helpers/provider_test_overrides.dart';

/// QW3 · QA-F-040 — Teacher leave request form validation gating
/// (`teacher_leave_screen.dart`) and class-teacher student-leave approvals
/// reject flow (`teacher_leave_approvals_screen.dart`). Neither was pumped.

/// Class teacher of 9-A so the seeded 9-A student-leave request becomes a
/// pending card this teacher owns (the demo approval seed files leave_stu_101
/// under classLabel 9-A).
const _classTeacher9A = TeacherTeachingContext(
  teacherId: 'HR-EMP-101',
  teacherName: 'Priya Sharma',
  commsRole: TeacherParentCommsRole.classTeacher,
  primarySubject: 'Mathematics',
  classTeacherGrade: '9',
  classTeacherSection: 'A',
  teachingClassLabels: ['9-A'],
);

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  useMobileViewport(tester);
  // Mock prefs so the leave-submit / reject audit + RBAC reads resolve.
  await initProviderTestPrefs();
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
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
  group('QA-F-040 · TeacherLeaveScreen apply form', () {
    testWidgets('Submit is disabled until the draft is valid', (tester) async {
      await _pump(
        tester,
        const TeacherLeaveScreen(),
        overrides: [
          teacherLeaveSectionProvider
              .overrideWith((ref) => TeacherLeaveSection.apply),
          teacherLeaveApplyDraftProvider
              .overrideWith((ref) => const TeacherLeaveApplyDraft()),
        ],
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit leave request'),
      );
      // Empty dates + short reason → invalid → disabled.
      expect(button.onPressed, isNull);
    });

    testWidgets('Submit enables for a valid draft and fires submit',
        (tester) async {
      await _pump(
        tester,
        const TeacherLeaveScreen(),
        overrides: [
          teacherLeaveSectionProvider
              .overrideWith((ref) => TeacherLeaveSection.apply),
          teacherLeaveApplyDraftProvider.overrideWith(
            (ref) => const TeacherLeaveApplyDraft(
              fromDateLabel: '12 Jun 2026',
              toDateLabel: '13 Jun 2026',
              reason: 'Fever and rest needed',
            ),
          ),
        ],
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit leave request'),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Submit leave request'));
      await tester.pumpAndSettle();

      // Successful submit surfaces the confirmation snackbar.
      expect(find.text('Leave request submitted.'), findsOneWidget);
    });
  });

  group('QA-F-040 · TeacherLeaveApprovalsScreen reject', () {
    testWidgets('renders a pending student-leave card with Reject/Approve',
        (tester) async {
      await _pump(
        tester,
        const TeacherLeaveApprovalsScreen(),
        overrides: [
          teacherTeachingContextOverrideProvider
              .overrideWith((ref) => _classTeacher9A),
        ],
      );

      expect(find.text('Student leave requests'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Reject'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
    });

    testWidgets('tapping Reject resolves the request and clears it from pending',
        (tester) async {
      await _pump(
        tester,
        const TeacherLeaveApprovalsScreen(),
        overrides: [
          teacherTeachingContextOverrideProvider
              .overrideWith((ref) => _classTeacher9A),
        ],
      );

      expect(find.widgetWithText(OutlinedButton, 'Reject'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
      await tester.pumpAndSettle();

      // Reject succeeds → confirmation snackbar + the card leaves the pending
      // list (back to the empty state). NOTE: the production screen rejects
      // immediately with a hard-coded 'Not approved' comment — there is no
      // comment-entry dialog (see FINDINGS).
      expect(find.text('Leave rejected'), findsOneWidget);
      expect(
        find.text('No pending leave requests for your class.'),
        findsOneWidget,
      );
    });
  });
}
