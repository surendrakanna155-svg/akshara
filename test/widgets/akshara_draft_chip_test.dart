import 'package:akshara_erp/shared/widgets/akshara_draft_chip.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-UX-1 slice 2c — draft chip + unsaved-changes PopScope guard.
void main() {
  group('AksharaDraftChip', () {
    testWidgets('renders the default "Draft saved" label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(body: AksharaDraftChip()),
        ),
      );
      await tester.pump();
      expect(find.text('Draft saved'), findsOneWidget);
    });
  });

  group('AksharaUnsavedChangesScope', () {
    Future<void> pumpForm(
      WidgetTester tester, {
      required bool dirty,
      VoidCallback? onDiscard,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Form')),
                        body: AksharaUnsavedChangesScope(
                          hasUnsavedChanges: dirty,
                          onDiscard: onDiscard,
                          child: const Center(child: Text('editing')),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('editing'), findsOneWidget);
    }

    testWidgets('no unsaved changes → back pops immediately', (tester) async {
      await pumpForm(tester, dirty: false);
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('editing'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('unsaved changes → confirm dialog; cancel keeps the form',
        (tester) async {
      await pumpForm(tester, dirty: true);
      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('editing'), findsOneWidget); // still on the form
    });

    testWidgets('unsaved changes → confirm Discard runs onDiscard and pops',
        (tester) async {
      var discarded = false;
      await pumpForm(tester, dirty: true, onDiscard: () => discarded = true);
      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(discarded, isTrue);
      expect(find.text('editing'), findsNothing);
    });
  });
}
