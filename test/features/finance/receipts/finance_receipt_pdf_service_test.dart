import 'package:akshara_erp/features/finance/receipts/finance_receipt_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildReceiptPdf returns non-empty bytes', () async {
    const service = FinanceReceiptPdfService();

    final bytes = await service.buildReceiptPdf(
      receiptNumber: 'RCP-2026-8841',
      schoolName: 'Akshara Public School',
      title: 'Term 1 Fee',
      dateLabel: '15 Apr 2026',
      paymentMethod: 'UPI',
      statusLabel: 'Paid',
      studentName: 'Ravi Kumar',
      classLabel: '8-A',
      lineItems: const [
        ReceiptPdfLineItem(label: 'Tuition', amount: 6000),
        ReceiptPdfLineItem(label: 'Activity', amount: 2000),
      ],
      totalAmount: 8000,
    );

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(500));
  });
}
