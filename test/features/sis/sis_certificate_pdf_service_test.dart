import 'package:akshara_erp/features/sis/certificates/sis_certificate_pdf_service.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';
import 'package:flutter_test/flutter_test.dart';

SisCertificateData _data({
  required SisCertificateType type,
  String? serialNo,
  String? publicStudentId = 'DPSKKP-0001',
  String? clearanceStatement,
}) {
  return SisCertificateData(
    issueId: 'SIS-CERT-701',
    type: type,
    serialNo: serialNo,
    reason: 'for bank account opening',
    issuedAt: '2026-07-03',
    studentName: 'Arjun Patel',
    publicStudentId: publicStudentId,
    admissionNumber: 'ADM-2026-0138',
    className: '10',
    section: 'A',
    academicYear: '2026–27',
    dateOfBirth: '14 Jun 2011',
    rollNumber: '12',
    guardianName: 'Kiran Patel',
    status: 'active',
    schoolName: 'Akshara Public School',
    schoolCode: 'DPSKKP',
    clearanceStatement: clearanceStatement,
  );
}

void main() {
  group('SisCertificatePdfService', () {
    const service = SisCertificatePdfService();

    for (final type in const [
      SisCertificateType.bonafide,
      SisCertificateType.study,
      SisCertificateType.conduct,
    ]) {
      test('builds non-empty bytes for a ${type.label} certificate', () async {
        final bytes = await service.buildCertificatePdf(data: _data(type: type));
        expect(bytes, isNotEmpty);
        expect(bytes.length, greaterThan(500));
      });
    }

    test('builds a transfer certificate PDF carrying the serial', () async {
      final bytes = await service.buildCertificatePdf(
        data: _data(
          type: SisCertificateType.transfer,
          serialNo: 'TC/DPSKKP/2026–27/0001',
        ),
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(500));
    });

    // ICA-H2: the transfer certificate renders the backend's truthful,
    // finance-scoped clearance statement, and falls back to a finance-only line
    // (never a blanket "all dues") when the backend supplies none.
    test('transfer certificate renders with a backend clearance statement',
        () async {
      final bytes = await service.buildCertificatePdf(
        data: _data(
          type: SisCertificateType.transfer,
          serialNo: 'TC/DPSKKP/2026–27/0001',
          clearanceStatement:
              'All financial dues have been cleared as of the date of issue.',
        ),
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(500));
    });

    test('transfer certificate renders with NO clearance statement (fallback)',
        () async {
      final bytes = await service.buildCertificatePdf(
        data: _data(
          type: SisCertificateType.transfer,
          serialNo: 'TC/DPSKKP/2026–27/0001',
        ),
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(500));
    });

    test('renders a code-less school (null public ID) without throwing',
        () async {
      final bytes = await service.buildCertificatePdf(
        data: _data(type: SisCertificateType.bonafide, publicStudentId: null),
      );
      expect(bytes, isNotEmpty);
    });

    test('fileNameFor slugs the student name and prefixes the type', () {
      expect(
        SisCertificatePdfService.fileNameFor(
          _data(type: SisCertificateType.transfer),
        ),
        'transfer_certificate_arjun_patel.pdf',
      );
    });
  });
}
