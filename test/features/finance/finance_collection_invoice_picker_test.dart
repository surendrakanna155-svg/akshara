import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_workflow_actions.dart';
import 'package:akshara_erp/features/finance/invoices/finance_invoices_provider.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

FinanceInvoice _invoice({
  required String id,
  required String number,
  required String term,
  required String outstanding,
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
  );
}

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  Widget buildHost() {
    return ProviderScope(
      overrides: providerTestOverrides([
        financeInvoicesProvider.overrideWithValue([
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
        ]),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
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

  testWidgets('record-collection dialog uses an invoice picker, not free text',
      (tester) async {
    await tester.pumpWidget(buildHost());
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The invoice field is now the searchable picker keyed for QA.
    expect(
      find.byKey(QaTestKeys.financeCollectionInvoiceField),
      findsOneWidget,
    );
    // It is pre-selected with a real invoice label (number · term · due).
    expect(find.textContaining('INV-2026-001'), findsOneWidget);
  });
}
