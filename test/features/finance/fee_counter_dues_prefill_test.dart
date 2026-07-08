import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_workflow_actions.dart';
import 'package:akshara_erp/features/finance/invoices/finance_invoices_provider.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

/// P2-UX-2 §2.4 — the fee counter shows REAL dues, never a hardcoded amount:
/// the record-collection dialog prefills the selected invoice's outstanding,
/// surfaces a live dues-breakdown line (incl. any late fee), and re-seeds the
/// amount when the cashier switches invoice. A caller-supplied dues figure (a
/// student's balance from the accounts search) wins for the initial amount.
FinanceInvoice _invoice({
  required String id,
  required String number,
  required String term,
  required String outstanding,
  String lateFee = '0',
}) {
  return FinanceInvoice(
    id: id,
    studentId: 'stu_1',
    feeAssignmentId: 'fa_1',
    academicYear: '2026-27',
    invoiceNumber: number,
    invoiceDate: '2026-04-01',
    dueDate: '2026-04-15',
    subtotalAmount: '10000',
    discountAmount: '0',
    totalAmount: '10000',
    outstandingAmount: outstanding,
    paidAmount: '0',
    invoiceStatus: InvoiceStatus.issued,
    termLabel: term,
    createdBy: 'system',
    createdAt: '2026-04-01',
    updatedAt: '2026-04-01',
    lateFeeAmount: lateFee,
  );
}

String _amountText(WidgetTester tester) {
  return tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(QaTestKeys.financeCollectionAmountField),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;
}

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  Widget buildHost({
    List<FinanceInvoice> invoices = const [],
    String? defaultAmount,
    String? studentLabel,
    String? duesLabel,
  }) {
    return ProviderScope(
      overrides: providerTestOverrides([
        financeInvoicesProvider.overrideWithValue(invoices),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showRecordCollectionDialog(
                  context,
                  ref,
                  defaultAmount: defaultAmount,
                  studentLabel: studentLabel,
                  duesLabel: duesLabel,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  final twoInvoices = [
    _invoice(
      id: 'inv_1',
      number: 'INV-2026-001',
      term: 'Term 1',
      outstanding: '5000',
    ),
    _invoice(
      id: 'inv_2',
      number: 'INV-2026-002',
      term: 'Term 2',
      outstanding: '7500',
    ),
  ];

  testWidgets('prefills the amount with the preferred invoice outstanding',
      (tester) async {
    await tester.pumpWidget(buildHost(invoices: twoInvoices));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Not the old hardcoded 5000-by-coincidence: it is inv_1's real outstanding.
    expect(_amountText(tester), '5000');
    // The live dues breakdown line is present with the real outstanding.
    expect(find.byKey(QaTestKeys.financeCollectionDuesLine), findsOneWidget);
    expect(find.text('Outstanding 5000'), findsOneWidget);
  });

  testWidgets('surfaces the accrued late fee in the dues breakdown',
      (tester) async {
    await tester.pumpWidget(
      buildHost(
        invoices: [
          _invoice(
            id: 'inv_1',
            number: 'INV-2026-001',
            term: 'Term 1',
            outstanding: '5000',
            lateFee: '250',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text('Outstanding 5000 · incl. late fee 250'),
      findsOneWidget,
    );
  });

  testWidgets('switching invoice re-seeds the amount + dues line',
      (tester) async {
    await tester.pumpWidget(buildHost(invoices: twoInvoices));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(_amountText(tester), '5000');

    // Open the invoice picker and choose Term 2 (inv_2, outstanding 7500).
    await tester.tap(find.byKey(QaTestKeys.financeCollectionInvoiceField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INV-2026-002 · Term 2 · 7500 due').last);
    await tester.pumpAndSettle();

    expect(_amountText(tester), '7500');
    expect(find.text('Outstanding 7500'), findsOneWidget);
  });

  testWidgets('a caller-supplied balance wins for the initial amount',
      (tester) async {
    await tester.pumpWidget(
      buildHost(
        invoices: twoInvoices,
        defaultAmount: '₹12,500',
        studentLabel: 'Rahul Sharma · ADM-2026-0138',
        duesLabel: 'Balance ₹12,500 · Class 8-A',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The seeded balance is cleaned to a plain number and wins over the invoice.
    expect(_amountText(tester), '12500');
    // The student context header renders.
    expect(find.text('Rahul Sharma · ADM-2026-0138'), findsOneWidget);
    expect(find.text('Balance ₹12,500 · Class 8-A'), findsOneWidget);
  });
}
