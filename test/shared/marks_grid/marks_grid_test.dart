import 'package:akshara_erp/shared/marks_grid/marks_grid.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-UX-2 §2.2/2.5 — the shared marks-grid kit both entry chains render.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  group('MarksColumnStats', () {
    testWidgets('shows entered / pending / average', (tester) async {
      await tester.pumpWidget(host(
        const MarksColumnStats(
          entered: 12,
          total: 40,
          averagePercent: 67.6,
          maxMarks: 50,
        ),
      ));
      expect(find.textContaining('12 / 40 entered'), findsOneWidget);
      expect(find.textContaining('28 pending'), findsOneWidget);
      expect(find.textContaining('avg 68%'), findsOneWidget);
      // Not complete → no "All entered" chip.
      expect(find.text('All entered'), findsNothing);
    });

    testWidgets('flags a fully-entered roster', (tester) async {
      await tester.pumpWidget(host(
        const MarksColumnStats(entered: 40, total: 40, averagePercent: 70),
      ));
      expect(find.text('All entered'), findsOneWidget);
      expect(find.textContaining('pending'), findsNothing);
    });
  });

  group('MarksCellSaveDot', () {
    testWidgets('renders a spinner while saving', (tester) async {
      await tester.pumpWidget(host(
        const MarksCellSaveDot(state: MarksCellState.saving),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders for each terminal state without error',
        (tester) async {
      for (final state in const [
        MarksCellState.empty,
        MarksCellState.unsaved,
        MarksCellState.saved,
        MarksCellState.error,
      ]) {
        await tester.pumpWidget(host(MarksCellSaveDot(state: state)));
        await tester.pump();
        expect(find.byType(MarksCellSaveDot), findsOneWidget);
      }
    });
  });

  group('MarksEntryField', () {
    testWidgets('is a locked number pad (digits only)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(
        MarksEntryField(controller: controller, maxMarks: 50),
      ));
      await tester.enterText(find.byType(TextField), 'a4b7c');
      await tester.pump();
      expect(controller.text, '47');
      expect(find.text('/50'), findsOneWidget);
    });

    testWidgets('fires onSubmitted (Enter advances the column)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var submitted = false;
      await tester.pumpWidget(host(
        MarksEntryField(
          controller: controller,
          maxMarks: 50,
          onSubmitted: () => submitted = true,
        ),
      ));
      await tester.enterText(find.byType(TextField), '30');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(submitted, isTrue);
    });
  });
}
