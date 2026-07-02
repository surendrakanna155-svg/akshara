import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_create_screen.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_provider.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_screen.dart';
import 'package:akshara_erp/features/teacher/homework/widgets/homework_submission_row.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../test_helpers.dart';
import '../../../helpers/provider_test_overrides.dart';

/// QW3 · QA-F-037 — Teacher homework create form validation gating, and
/// QA-F-039 — Teacher homework review screen grade flow (Save review → reviewed).
/// Both screens shared the TA-04 homework module and were never widget-pumped.

GoRouter _routerFor(Widget screen) => GoRouter(
      initialLocation: '/hw',
      routes: [
        GoRoute(path: '/hw', builder: (context, state) => screen),
        GoRoute(
          path: RouteNames.teacherHomework,
          builder: (context, state) => const Scaffold(body: Text('homework-list')),
        ),
        GoRoute(
          path: RouteNames.aiAssistant,
          builder: (context, state) => const Scaffold(body: Text('ai')),
        ),
        GoRoute(
          path: RouteNames.parentNotifications,
          builder: (context, state) => const Scaffold(body: Text('notifs')),
        ),
        GoRoute(
          path: RouteNames.teacherDashboard,
          builder: (context, state) => const Scaffold(body: Text('dash')),
        ),
      ],
    );

Future<void> _pumpRouter(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  useMobileViewport(tester);
  // Wire mock SharedPreferences so the create/review mutations' audit-log write
  // succeeds (otherwise the audit logger throws → mutation reports an error and
  // the post-success navigation / reviewed-state update never fires).
  await initProviderTestPrefs();
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        routerConfig: _routerFor(screen),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-037 · TeacherHomeworkCreateScreen', () {
    testWidgets('blank required fields block submit with Required errors',
        (tester) async {
      await _pumpRouter(tester, const TeacherHomeworkCreateScreen());

      // Clear the prefilled subject so the form is empty. (HWK-3: the class
      // prefill lands as a chip, so the class requirement is already satisfied
      // — the empty subject + title + missing due date must still block submit.)
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Subject'), '');

      await tester.tap(find.byKey(QaTestKeys.teacherHomeworkCreateButton));
      await tester.pumpAndSettle();

      // Subject + title report 'Required' and the (HWK-1) due-date field reports
      // its own 'Pick a due date' error; the screen stays put — no navigation
      // to the homework list.
      expect(find.text('Required'), findsNWidgets(2));
      expect(find.text('Pick a due date'), findsOneWidget);
      expect(find.text('homework-list'), findsNothing);
      expect(find.text('Create Homework'), findsOneWidget);
    });

    testWidgets(
        'valid form with a picked due date fires Create and navigates to the list',
        (tester) async {
      await _pumpRouter(tester, const TeacherHomeworkCreateScreen());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Class label'), '8-A');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Subject'), 'Mathematics');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Assignment title (English)'),
          'Algebra worksheet');

      // HWK-1 — pick a real due date via the Material date picker (defaults to
      // today), then confirm with OK.
      await tester.tap(find.byKey(QaTestKeys.teacherHomeworkDueDateField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The field now shows a formatted date instead of the placeholder.
      expect(find.text('Select a due date'), findsNothing);

      await tester.tap(find.byKey(QaTestKeys.teacherHomeworkCreateButton));
      await tester.pumpAndSettle();

      // No validation errors; create succeeded and routed to the list.
      expect(find.text('Required'), findsNothing);
      expect(find.text('Pick a due date'), findsNothing);
      expect(find.text('homework-list'), findsOneWidget);
    });
  });

  group('QA-F-039 · TeacherHomeworkScreen review', () {
    testWidgets('renders the pending submissions for the default assignment',
        (tester) async {
      await _pumpRouter(tester, const TeacherHomeworkScreen());

      expect(find.text('Homework Review'), findsOneWidget);
      expect(find.byType(HomeworkSubmissionRow), findsWidgets);
      // Default assignment hw_8a_1 has pending submissions seeded.
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
    });

    testWidgets('grading a submission marks it reviewed via the review sheet',
        (tester) async {
      await _pumpRouter(tester, const TeacherHomeworkScreen());

      // Open the review sheet for the first pending submission.
      await tester.tap(find.text('Ravi Kumar'));
      await tester.pumpAndSettle();

      expect(find.text('Review Ravi Kumar'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Grade'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Comment'), 'Neat work');
      await tester.tap(find.widgetWithText(FilledButton, 'Save review'));
      await tester.pumpAndSettle();

      // Sheet dismissed; Ravi's row now shows the grade + the comment we typed
      // (distinct from the pre-seeded reviewed submission's "Excellent steps").
      expect(find.text('Review Ravi Kumar'), findsNothing);
      expect(find.textContaining('Neat work'), findsOneWidget);
      expect(find.text('Reviewed'), findsWidgets);
    });

    testWidgets('shows the loading and error states when forced',
        (tester) async {
      await _pumpRouter(
        tester,
        const TeacherHomeworkScreen(),
        overrides: [
          teacherHomeworkErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(find.text('Unable to load homework submissions.'), findsOneWidget);
      expect(find.byType(HomeworkSubmissionRow), findsNothing);
    });
  });
}
