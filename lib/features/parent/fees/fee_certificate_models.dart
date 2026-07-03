import 'package:flutter/foundation.dart';

/// PAR-D3 — an annual (Section 80C) fee-payment certificate for the active
/// child, built server-side from the year's completed receipts. The server
/// scopes every row to the caller's own children (never a client-supplied
/// student id), so this model carries only what the certificate renders.
@immutable
class FeeCertificateData {
  const FeeCertificateData({
    required this.schoolName,
    required this.guardianName,
    required this.studentName,
    required this.academicYear,
    required this.totalPaidAmount,
    required this.payments,
    required this.signatoryTitle,
    this.publicStudentId,
    this.admissionNumber,
  });

  /// School letterhead name.
  final String schoolName;

  /// The guardian (the requesting parent) — the "paid by" line.
  final String guardianName;

  /// Child the certificate is for.
  final String studentName;

  /// Public student id (e.g. `DPSKKP-0001`); may be absent for legacy students.
  final String? publicStudentId;

  /// School-configurable admission number; separate from the public id.
  final String? admissionNumber;

  /// Financial-year label, e.g. `2025-2026`.
  final String academicYear;

  /// Sum of the year's completed payments (rupees).
  final double totalPaidAmount;

  /// The year's payments, oldest first.
  final List<FeeCertificatePayment> payments;

  /// Signatory line, e.g. `Principal` (per-school configurable).
  final String signatoryTitle;

  /// True when there is nothing to certify for the requested year.
  bool get isEmpty => totalPaidAmount == 0 && payments.isEmpty;
}

/// A single fee payment on the certificate.
@immutable
class FeeCertificatePayment {
  const FeeCertificatePayment({
    required this.date,
    required this.receiptNo,
    required this.amount,
    required this.paymentMethod,
    required this.description,
  });

  /// Human date label, e.g. `15 Apr 2025`.
  final String date;

  /// Receipt number.
  final String receiptNo;

  /// Amount paid (rupees).
  final double amount;

  /// Payment method label, e.g. `UPI`.
  final String paymentMethod;

  /// Line description, e.g. `Fee payment · INV-2025-0007`.
  final String description;
}
