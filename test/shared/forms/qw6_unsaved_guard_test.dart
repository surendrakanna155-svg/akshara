import 'package:akshara_erp/shared/forms/akshara_unsaved_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW6 · QA-X-009 — unsaved-changes guard on navigate-away during a write.
///
/// Red Team Wave 4 (RT-30) added the in-app `PopScope` guard + web
/// `beforeunload`; this row adds the missing automated proof that navigating
/// away mid-edit prompts a confirm-discard dialog and prevents silent loss of an
/// in-flight write (e.g. an exam marks grid or enrollment wizard).
void main() {
  Future<void> pumpFormBehind(
    WidgetTester tester, {
    required bool dirty,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Edit marks')),
                      body: AksharaUnsavedChangesGuard(
                        hasUnsavedChanges: dirty,
                        child: const Text('marks grid'),
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
    expect(find.text('marks grid'), findsOneWidget);
  }

  testWidgets('dirty form prompts confirm-discard on back; "Keep editing" stays',
      (tester) async {
    await pumpFormBehind(tester, dirty: true);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('marks grid'), findsOneWidget,
        reason: 'work is preserved — the route did not pop');
  });

  testWidgets('"Discard" confirms and pops the route', (tester) async {
    await pumpFormBehind(tester, dirty: true);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('marks grid'), findsNothing);
    expect(find.text('open'), findsOneWidget,
        reason: 'after discard, navigation completes back to the caller');
  });

  testWidgets('clean form pops immediately with no prompt', (tester) async {
    await pumpFormBehind(tester, dirty: false);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('marks grid'), findsNothing,
        reason: 'no unsaved work → back navigates straight through');
  });
}
