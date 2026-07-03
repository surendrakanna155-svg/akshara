import '../../../features/sis/sis_models.dart';
import '../../../features/sis/sis_requests.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for student SIS data access (mock or API).
abstract class SisRepository {
  Future<SisDashboardData> getDashboard({required RepositoryQuery query});

  Future<PaginatedResult<SisStudent>> getStudents(
      {required RepositoryQuery query});

  Future<SisStudentProfile> getStudentProfile({
    required RepositoryQuery query,
    required String studentId,
  });

  Future<SisAcademicAssignmentData> getAcademicAssignment({
    required RepositoryQuery query,
  });

  Future<SisAdmissionsConversionData> getAdmissionsConversion({
    required RepositoryQuery query,
  });

  Future<SisStudent> createStudent({
    required RepositoryQuery query,
    required CreateStudentRequest request,
  });

  Future<SisStudent> updateStudent({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentRequest request,
  });

  Future<SisDocumentSummary> uploadStudentDocument({
    required RepositoryQuery query,
    required String studentId,
    required UploadStudentDocumentRequest request,
  });

  /// SIS-3 — marks a pending student document verified or rejected
  /// (manageSis). Returns the updated document incl. status / verifiedBy.
  Future<SisDocumentSummary> verifyStudentDocument({
    required RepositoryQuery query,
    required String studentId,
    required String documentId,
    required VerifyStudentDocumentRequest request,
  });

  /// SIS-5 — date-ranged, exportable list of exited students (transferred /
  /// alumni) with last-enrollment context (viewSis). Page/pageSize ride on
  /// [query]; [fromDate]/[toDate] are ISO dates; [status] narrows to
  /// transferred or alumni.
  Future<PaginatedResult<SisTransferRecord>> listStudentTransfers({
    required RepositoryQuery query,
    String? fromDate,
    String? toDate,
    SisStudentStatus? status,
  });

  Future<SisStudent> updateStudentStatus({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentStatusRequest request,
  });

  /// SIS-1 — issues a bonafide/study/conduct certificate for a student
  /// (manageSis) and returns the certificate data for the client PDF.
  Future<SisCertificateData> issueCertificate({
    required RepositoryQuery query,
    required String studentId,
    required IssueCertificateRequest request,
  });

  /// SIS-D1 — issues a Transfer Certificate (manageSis). Throws when the student
  /// still has outstanding fees (409 DUES_PENDING) — nothing is written; on
  /// success the student's status auto-transitions to transferred.
  Future<SisCertificateData> issueTransferCertificate({
    required RepositoryQuery query,
    required String studentId,
    required IssueTransferCertificateRequest request,
  });

  /// SIS-1 — the certificate issuance register for a student (viewSis),
  /// newest first.
  Future<List<SisCertificateIssue>> listCertificates({
    required RepositoryQuery query,
    required String studentId,
  });

  Future<SisStudent> assignAcademicAssignment({
    required RepositoryQuery query,
    required AcademicAssignmentRequest request,
  });

  Future<SisConversionPreview> convertAdmissionsEnrollment({
    required RepositoryQuery query,
    required AdmissionsConversionRequest request,
  });
}
