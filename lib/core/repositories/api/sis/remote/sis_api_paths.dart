/// REST paths for the SIS API module.
abstract final class SisApiPaths {
  static const String base = '/sis';

  static const String dashboard = '$base/dashboard';
  static const String students = '$base/students';
  static const String enrollments = '$base/enrollments';
  static const String admissionsConversion = '$base/admissions-conversion';

  /// SIS-5 — GET transfers / exit log.
  static const String transfers = '$base/transfers';

  /// @deprecated Use [enrollments] — retained for mock/catalog references only.
  static const String academicAssignment = '$base/academic-assignment';

  static String studentProfile(String studentId) => '$base/students/$studentId';

  static String studentStatus(String studentId) =>
      '$base/students/$studentId/status';

  static String studentDocuments(String studentId) =>
      '$base/students/$studentId/documents';

  /// PRA-P1-19 — POST presign a real document upload (before confirm).
  static String studentDocumentsPresign(String studentId) =>
      '$base/students/$studentId/documents/presign';

  /// PRA-P1-19 — GET a short-lived signed download URL for a stored document.
  static String studentDocumentDownload(String studentId, String documentId) =>
      '$base/students/$studentId/documents/$documentId/download';

  /// SIS-4 — GET a student's siblings / family (read-only).
  static String studentSiblings(String studentId) =>
      '$base/students/$studentId/siblings';

  /// SIS-3 — PATCH verify/reject a student document.
  static String studentDocumentVerify(String studentId, String documentId) =>
      '$base/students/$studentId/documents/$documentId/verify';

  static String enrollment(String enrollmentId) =>
      '$base/enrollments/$enrollmentId';

  /// SIS-1 — POST issue / GET the certificate register for a student.
  static String studentCertificates(String studentId) =>
      '$base/students/$studentId/certificates';

  /// SIS-D1 — POST issue a Transfer Certificate for a student.
  static String studentTransferCertificate(String studentId) =>
      '$base/students/$studentId/transfer-certificate';
}
