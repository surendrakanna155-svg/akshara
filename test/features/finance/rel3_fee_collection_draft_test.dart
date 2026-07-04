import 'package:akshara_erp/core/reliability/reliability_providers.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/tenant/tenant_context.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/finance_workflow_actions.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// REL-3 — the "Record collection" money form autosaves an in-progress draft and
/// offers to resume it on reopen. Because it is a money form, the amount is never
/// silently prefilled: the cashier explicitly chooses Resume or Discard.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryReliabilityStore sharedStore;

  setUp(() {
    sharedStore = InMemoryReliabilityStore();
  });

  Widget harness() {
    return ProviderScope(
      overrides: [
        reliabilityStoreProvider.overrideWithValue(sharedStore),
        // A fixed tenant so the draft controller has a stable user scope without
        // standing up the full auth/session stack.
        tenantContextProvider.overrideWithValue(
          TenantContext.demo.copyWith(userId: 'user-test'),
        ),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: ElevatedButton(
                onPressed: () => showRecordCollectionDialog(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'REL-3: a half-entered collection is autosaved and resumed on reopen',
      (tester) async {
    await tester.pumpWidget(harness());

    // Open the dialog and type a (non-default) amount.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final amountField = find.byKey(QaTestKeys.financeCollectionAmountField);
    expect(amountField, findsOneWidget);
    await tester.enterText(amountField, '2500');
    // Let the autosave debounce elapse + the async save land.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // Dismiss the dialog WITHOUT recording (interruption).
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Reopen — the resume prompt appears, but the amount is NOT auto-filled.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(QaTestKeys.financeCollectionDraftResumeButton),
      findsOneWidget,
    );
    // Money-safe: the field still shows the default, not the drafted amount.
    expect(
      tester.widget<TextField>(
        find.descendant(
          of: amountField,
          matching: find.byType(TextField),
        ),
      ).controller!.text,
      isNot('2500'),
    );

    // Resume → the drafted amount is restored.
    await tester.tap(find.byKey(QaTestKeys.financeCollectionDraftResumeButton));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(
        find.descendant(
          of: amountField,
          matching: find.byType(TextField),
        ),
      ).controller!.text,
      '2500',
    );
  });

  testWidgets('REL-3: discarding the draft stops it being re-offered',
      (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(QaTestKeys.financeCollectionAmountField),
      '1800',
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Reopen → Discard the offered draft.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QaTestKeys.financeCollectionDraftDiscardButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Reopen again → no resume prompt (the draft was cleared).
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(QaTestKeys.financeCollectionDraftResumeButton),
      findsNothing,
    );
  });
}
