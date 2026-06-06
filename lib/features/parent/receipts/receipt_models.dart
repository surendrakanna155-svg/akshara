import 'package:flutter/foundation.dart';

/// Receipt list filters for PA-11.
enum ReceiptFilter { all, term, transport, admission }

extension ReceiptFilterX on ReceiptFilter {
  String get label {
    return switch (this) {
      ReceiptFilter.all => 'All',
      ReceiptFilter.term => 'Term fees',
      ReceiptFilter.transport => 'Transport',
      ReceiptFilter.admission => 'Admission',
    };
  }
}

/// Fee receipt row and detail model.
@immutable
class FeeReceipt {
  const FeeReceipt({
    required this.id,
    required this.receiptNumber,
    required this.title,
    required this.dateLabel,
    required this.amount,
    required this.paymentMethod,
    required this.statusLabel,
    required this.childName,
    required this.childClass,
    required this.category,
    required this.lineItems,
    this.schoolName = 'Akshara Public School',
  });

  final String id;
  final String receiptNumber;
  final String title;
  final String dateLabel;
  final int amount;
  final String paymentMethod;
  final String statusLabel;
  final String childName;
  final String childClass;
  final String category;
  final List<ReceiptLineItem> lineItems;
  final String schoolName;
}

@immutable
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.label,
    required this.amount,
  });

  final String label;
  final int amount;
}
