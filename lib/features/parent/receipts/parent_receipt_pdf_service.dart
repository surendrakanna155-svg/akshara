import 'dart:typed_data';

import '../../finance/finance_models.dart';
import '../../finance/receipts/finance_receipt_pdf_service.dart';
import 'receipt_models.dart';

class ParentReceiptPdfService {
  ParentReceiptPdfService({
    FinanceReceiptPdfService? financePdfService,
  }) : _financePdfService = financePdfService ?? const FinanceReceiptPdfService();

  final FinanceReceiptPdfService _financePdfService;

  Future<Uint8List> buildReceiptPdf(
    FeeReceipt receipt, {
    FinanceReceiptDetail? financeReceipt,
  }) {
    return _financePdfService.buildReceiptPdf(
      receiptNumber: receipt.receiptNumber,
      schoolName: receipt.schoolName,
      title: receipt.title,
      dateLabel: receipt.dateLabel,
      paymentMethod: receipt.paymentMethod,
      statusLabel: receipt.statusLabel,
      studentName: receipt.childName,
      classLabel: receipt.childClass,
      lineItems: [
        for (final line in receipt.lineItems)
          ReceiptPdfLineItem(label: line.label, amount: line.amount),
      ],
      totalAmount: receipt.amount,
      financeReceipt: financeReceipt,
    );
  }

  Future<void> printReceipt(Uint8List bytes) {
    return _financePdfService.printReceipt(bytes);
  }

  Future<void> shareReceipt({
    required Uint8List bytes,
    required String receiptNumber,
  }) {
    return _financePdfService.shareReceipt(
      bytes: bytes,
      fileName: '$receiptNumber.pdf',
    );
  }
}
