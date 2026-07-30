import 'package:akshara_erp/core/repositories/mock/mock_student_write_store.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/student_app/homework/student_homework_provider.dart';
import 'package:akshara_erp/features/student_app/homework/student_homework_screen.dart';
import 'package:akshara_erp/features/student_app/homework/widgets/homework_list_row.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// QW3 · QA-F-042 — Student homework submit flow + error surface.
/// `student_homework_screen.dart` (ST-04) was never widget-pumped. Demo data
/// seeds a pending item (hw-1, Mathematics) with a Submit action; tapping it
/// runs the submit mutation and the row flips to the submitted state.
/// NOTE: titles render in the student's preferred language (Telugu in the demo
/// persona), so assertions key on the stable, non-localized subject / status /
/// attachment / button labels.

Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  useMobileViewport(tester);
  // Mock prefs so the submit mutation's audit-log write succeeds.
  await initProviderTestPrefs();
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const StudentHomeworkScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  // The submit mutation writes to a singleton store; keep tests order-free.
  setUp(() => MockStudentWriteStore.instance.submittedHomework.clear());
  tearDown(() => MockStudentWriteStore.instance.submittedHomework.clear());

  group('QA-F-042 · StudentHomeworkScreen', () {
    testWidgets('renders KPI strip + homework rows with a pending Submit',
        (tester) async {
      await _pump(tester);

      expect(find.text('Homework'), findsOneWidget);
      expect(find.byType(HomeworkListRow), findsWidgets);
      // The pending item exposes its subject + attachment.
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('worksheet_5_2.pdf'), findsOneWidget);
      // HWK-7 — two actionable items expose a Submit action: hw-1 (pending) and
      // hw-2 (overdue — late submission is now allowed).
      expect(find.widgetWithText(FilledButton, 'Submit'), findsNWidgets(2));
    });

    testWidgets('submitting via the HWK-7 sheet transitions the item',
        (tester) async {
      await _pump(tester);

      // Two actionable Submit actions before the tap (pending + overdue).
      expect(find.widgetWithText(FilledButton, 'Submit'), findsNWidgets(2));

      // Tap the first (pending) item's Submit → the HWK-7 submit sheet opens.
      final submit = find.widgetWithText(FilledButton, 'Submit').first;
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      // The sheet offers optional note + attachment fields and a confirm button.
      expect(
        find.byKey(QaTestKeys.studentHomeworkSubmitConfirmButton),
        findsOneWidget,
      );
      await tester
          .tap(find.byKey(QaTestKeys.studentHomeworkSubmitConfirmButton));
      await tester.pumpAndSettle();

      // After the submit mutation the pending row flips to submitted, so only
      // the still-overdue item's Submit action remains.
      expect(find.widgetWithText(FilledButton, 'Submit'), findsOneWidget);
    });

    testWidgets('forced error renders the error surface with retry',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          studentHomeworkErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(find.text('Unable to load homework right now.'), findsOneWidget);
      expect(find.byType(HomeworkListRow), findsNothing);
    });
  });
}
