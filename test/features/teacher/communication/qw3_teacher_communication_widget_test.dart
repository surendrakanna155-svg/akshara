import 'package:akshara_erp/features/teacher/communication/teacher_parent_communication_provider.dart';
import 'package:akshara_erp/features/teacher/communication/teacher_parent_communication_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';
import '../../../helpers/provider_test_overrides.dart';

/// QW3 · QA-F-041 — Teacher → parent AI custom-message generate + send.
/// `teacher_parent_communication_screen.dart` was never widget-pumped. The
/// default demo persona (Priya Sharma) is class teacher 8-A so the direct
/// send + AI-generate path (canSend == true) renders; we pre-select an 8-A
/// student (the dropdown's only effect is setting this provider) and drive the
/// "Generate custom message (AI)" dialog to its send. The send button + AI
/// button sit low in a ListView, so each is scrolled into view before tapping.

// Ravi Kumar — Class 8-A, in Priya's class-teacher scope (primary mobile
// persona, the one student with a parent phone number wired for delivery).
const _student8aId = 'SIS-STU-10430';

Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  useMobileViewport(tester);
  await initProviderTestPrefs();
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const TeacherParentCommunicationScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

/// Scrolls [target] into view within the screen's ListView before acting.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-041 · TeacherParentCommunicationScreen', () {
    testWidgets('renders the class-teacher send workflow with AI generate',
        (tester) async {
      await _pump(tester);

      expect(find.text('Parent communication'), findsOneWidget);

      await _scrollTo(
        tester,
        find.widgetWithText(OutlinedButton, 'Generate custom message (AI)'),
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Generate custom message (AI)'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Send to parent'),
        findsOneWidget,
      );
    });

    testWidgets('AI generate is gated until a student is selected',
        (tester) async {
      await _pump(tester);

      await _scrollTo(
        tester,
        find.widgetWithText(OutlinedButton, 'Generate custom message (AI)'),
      );

      // No student selected → both AI-generate and send are disabled.
      final aiButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Generate custom message (AI)'),
      );
      final sendButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send to parent'),
      );
      expect(aiButton.onPressed, isNull);
      expect(sendButton.onPressed, isNull);
    });

    testWidgets('generate AI dialog confirms and fires the send',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          // The Student dropdown's sole effect is setting this provider.
          teacherCommunicationSelectedStudentProvider
              .overrideWith((ref) => _student8aId),
        ],
      );

      await _scrollTo(
        tester,
        find.widgetWithText(OutlinedButton, 'Generate custom message (AI)'),
      );

      final aiButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Generate custom message (AI)'),
      );
      expect(aiButton.onPressed, isNotNull);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Generate custom message (AI)'),
      );
      await tester.pumpAndSettle();

      // The AI compose dialog opens.
      expect(find.text('Custom message (AI)'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).last,
        'Please update the parent on recent progress.',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Generate & send'));
      await tester.pumpAndSettle();

      // Dialog dismissed + AI send confirmation surfaces.
      expect(find.text('Custom message (AI)'), findsNothing);
      expect(find.text('Custom AI message sent.'), findsOneWidget);
    });

    testWidgets('Send to parent fires for a selected student + channel',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          teacherCommunicationSelectedStudentProvider
              .overrideWith((ref) => _student8aId),
        ],
      );

      await _scrollTo(
        tester,
        find.widgetWithText(FilledButton, 'Send to parent'),
      );

      final sendButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send to parent'),
      );
      // In-App channel is on by default → send enabled.
      expect(sendButton.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Send to parent'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sent to'), findsOneWidget);
    });
  });
}
