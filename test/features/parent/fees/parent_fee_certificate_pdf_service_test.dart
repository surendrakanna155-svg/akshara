import 'dart:typed_data';

import 'package:akshara_erp/features/parent/fees/fee_certificate_models.dart';
import 'package:akshara_erp/features/parent/fees/parent_fee_certificate_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _certificate = FeeCertificateData(
  schoolName: 'NIKSHA Public School',
  guardianName: 'Suresh Kumar',
  studentName: 'Ravi Kumar',
  publicStudentId: 'AKPS-0042',
  admissionNumber: 'ADM-2026-0842',
  academicYear: '2025-2026',
  totalPaidAmount: 30000,
  payments: [
    FeeCertificatePayment(
      date: '15 Apr 2025',
      receiptNo: 'RCP-2025-8841',
      amount: 18000,
      paymentMethod: 'UPI',
      description: 'Fee payment · INV-2025-0007',
    ),
    FeeCertificatePayment(
      date: '10 Sep 2025',
      receiptNo: 'RCP-2025-9204',
      amount: 12000,
      paymentMethod: 'Card',
      description: 'Fee payment · INV-2025-0118',
    ),
  ],
  signatoryTitle: 'Principal',
);

const _emptyCertificate = FeeCertificateData(
  schoolName: 'NIKSHA Public School',
  guardianName: 'Suresh Kumar',
  studentName: 'Ravi Kumar',
  academicYear: '2024-2025',
  totalPaidAmount: 0,
  payments: [],
  signatoryTitle: 'Principal',
);

void main() {
  group('ParentFeeCertificatePdfService', () {
    test('buildCertificatePdf returns non-empty bytes', () async {
      final service = ParentFeeCertificatePdfService();
      final bytes = await service.buildCertificatePdf(_certificate);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(500));
    });

    test('buildCertificatePdf renders a zero-payment year without throwing',
        () async {
      final service = ParentFeeCertificatePdfService();
      final bytes = await service.buildCertificatePdf(_emptyCertificate);
      expect(bytes, isNotEmpty);
    });

    test('printCertificate routes through the injected layout hook', () async {
      Uint8List? printed;
      final service = ParentFeeCertificatePdfService(
        layoutPdf: (bytes) async => printed = bytes,
      );
      final bytes = await service.buildCertificatePdf(_certificate);
      await service.printCertificate(bytes);
      expect(printed, same(bytes));
    });

    test('shareCertificate routes through the injected share hook', () async {
      String? sharedName;
      Uint8List? sharedBytes;
      final service = ParentFeeCertificatePdfService(
        sharePdf: ({required bytes, required filename}) async {
          sharedBytes = bytes;
          sharedName = filename;
        },
      );
      final bytes = await service.buildCertificatePdf(_certificate);
      await service.shareCertificate(bytes: bytes, academicYear: '2025-2026');
      expect(sharedBytes, same(bytes));
      expect(sharedName, 'fee_certificate_2025_2026.pdf');
    });

    test('fileNameFor sanitizes the academic year', () {
      expect(
        ParentFeeCertificatePdfService.fileNameFor('2025-2026'),
        'fee_certificate_2025_2026.pdf',
      );
      expect(
        ParentFeeCertificatePdfService.fileNameFor('   '),
        'fee_certificate_certificate.pdf',
      );
    });
  });
}
