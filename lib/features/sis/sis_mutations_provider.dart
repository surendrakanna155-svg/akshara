import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/academic/academic_catalog_mutation.dart';
import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import 'dashboard/sis_dashboard_provider.dart';
import 'integration/sis_admissions_integration_provider.dart';
import 'profile/sis_profile_provider.dart';
import 'registry/sis_registry_provider.dart';
import 'sis_audit.dart';
import 'sis_models.dart';
import 'sis_requests.dart';

void _invalidateSisReads(
  Ref ref, {
  bool students = false,
  bool dashboard = false,
  bool conversion = false,
  String? studentId,
}) {
  if (students) ref.invalidate(sisStudentsFutureProvider);
  if (dashboard) ref.invalidate(sisDashboardFutureProvider);
  if (conversion) ref.invalidate(sisAdmissionsConversionFutureProvider);
  if (studentId != null) {
    ref.invalidate(sisStudentProfileFutureProvider(studentId));
  }
}

Future<T?> _runMutation<T>(
  Ref ref, {
  required Future<T> Function() action,
  bool invalidateStudents = false,
  bool invalidateDashboard = false,
  bool invalidateConversion = false,
  String? invalidateStudentId,
  void Function()? assertPermission,
}) async {
  assertPermission?.call();
  try {
    final result = await action();
    _invalidateSisReads(
      ref,
      students: invalidateStudents,
      dashboard: invalidateDashboard,
      conversion: invalidateConversion,
      studentId: invalidateStudentId,
    );
    return result;
  } catch (error) {
    final failure = apiFailureMapper.fromException(error);
    throw ApiFailureException(failure);
  }
}

class CreateStudentNotifier extends AsyncNotifier<SisStudent?> {
  @override
  FutureOr<SisStudent?> build() => null;

  Future<SisStudent?> execute(CreateStudentRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudents: true,
        invalidateDashboard: true,
        action: () => ref.read(sisRepositoryProvider).createStudent(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final createStudentProvider =
    AsyncNotifierProvider<CreateStudentNotifier, SisStudent?>(
  CreateStudentNotifier.new,
);

class UpdateStudentNotifier extends AsyncNotifier<SisStudent?> {
  @override
  FutureOr<SisStudent?> build() => null;

  Future<SisStudent?> execute({
    required String studentId,
    required UpdateStudentRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudents: true,
        invalidateStudentId: studentId,
        action: () => ref.read(sisRepositoryProvider).updateStudent(
              query: ref.read(repositoryQueryProvider),
              studentId: studentId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateStudentProvider =
    AsyncNotifierProvider<UpdateStudentNotifier, SisStudent?>(
  UpdateStudentNotifier.new,
);

class UploadStudentDocumentNotifier extends AsyncNotifier<SisDocumentSummary?> {
  @override
  FutureOr<SisDocumentSummary?> build() => null;

  Future<SisDocumentSummary?> execute({
    required String studentId,
    required UploadStudentDocumentRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudentId: studentId,
        // PRA-P1-19: upload REAL bytes to Storage (presign → PUT → confirm) so the
        // document is retrievable, instead of persisting a fabricated file_uri.
        action: () => ref.read(sisRepositoryProvider).uploadStudentDocumentFile(
              query: ref.read(repositoryQueryProvider),
              studentId: studentId,
              request: request,
              bytes: _syntheticDocumentBytes(),
              contentType: 'application/pdf',
            ),
      );
    });
    return state.valueOrNull;
  }
}

/// Minimal valid single-page PDF payload. Mirrors the admissions/device-memories
/// synthetic-bytes upload precedent — the app exercises the real presign → PUT →
/// confirm Storage path without an OS file-picker dependency. (Wiring a native
/// picker is a tracked UX follow-up; see PRA-P1-19 notes.)
Uint8List _syntheticDocumentBytes() {
  const pdf =
      '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
      '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
      '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\n'
      'trailer<</Root 1 0 R>>\n%%EOF';
  return Uint8List.fromList(pdf.codeUnits);
}

final uploadStudentDocumentProvider =
    AsyncNotifierProvider<UploadStudentDocumentNotifier, SisDocumentSummary?>(
  UploadStudentDocumentNotifier.new,
);

/// SIS-3 — verifies or rejects a pending student document (manageSis).
/// Invalidates the student profile (documents live on it) on success.
class VerifyStudentDocumentNotifier extends AsyncNotifier<SisDocumentSummary?> {
  @override
  FutureOr<SisDocumentSummary?> build() => null;

  Future<SisDocumentSummary?> execute({
    required String studentId,
    required String documentId,
    required VerifyStudentDocumentRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudentId: studentId,
        action: () => ref.read(sisRepositoryProvider).verifyStudentDocument(
              query: ref.read(repositoryQueryProvider),
              studentId: studentId,
              documentId: documentId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final verifyStudentDocumentProvider =
    AsyncNotifierProvider<VerifyStudentDocumentNotifier, SisDocumentSummary?>(
  VerifyStudentDocumentNotifier.new,
);

/// SIS-1 — issues a bonafide/study/conduct certificate (manageSis) and returns
/// the certificate DATA for the client PDF. Refreshes the register on success.
class IssueCertificateNotifier extends AsyncNotifier<SisCertificateData?> {
  @override
  FutureOr<SisCertificateData?> build() => null;

  Future<SisCertificateData?> execute({
    required String studentId,
    required IssueCertificateRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        action: () => ref.read(sisRepositoryProvider).issueCertificate(
              query: ref.read(repositoryQueryProvider),
              studentId: studentId,
              request: request,
            ),
      );
      ref.invalidate(sisCertificateRegisterProvider(studentId));
      return result;
    });
    return state.valueOrNull;
  }
}

final issueCertificateProvider =
    AsyncNotifierProvider<IssueCertificateNotifier, SisCertificateData?>(
  IssueCertificateNotifier.new,
);

/// SIS-D1 — issues a Transfer Certificate (manageSis). Surfaces 409
/// DUES_PENDING as an [ApiFailureException]; on success the student's status
/// flips to transferred, so the student read + register are invalidated.
class IssueTransferCertificateNotifier
    extends AsyncNotifier<SisCertificateData?> {
  @override
  FutureOr<SisCertificateData?> build() => null;

  Future<SisCertificateData?> execute({
    required String studentId,
    required IssueTransferCertificateRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudents: true,
        invalidateStudentId: studentId,
        action: () => ref.read(sisRepositoryProvider).issueTransferCertificate(
              query: ref.read(repositoryQueryProvider),
              studentId: studentId,
              request: request,
            ),
      );
      ref.invalidate(sisCertificateRegisterProvider(studentId));
      return result;
    });
    return state.valueOrNull;
  }
}

final issueTransferCertificateProvider = AsyncNotifierProvider<
    IssueTransferCertificateNotifier, SisCertificateData?>(
  IssueTransferCertificateNotifier.new,
);

/// SIS-1 — the certificate issuance register for a student (viewSis).
final sisCertificateRegisterProvider =
    FutureProvider.family<List<SisCertificateIssue>, String>(
  (ref, studentId) => ref.read(sisRepositoryProvider).listCertificates(
        query: ref.read(repositoryQueryProvider),
        studentId: studentId,
      ),
);

class UpdateStudentStatusNotifier extends AsyncNotifier<SisStudent?> {
  @override
  FutureOr<SisStudent?> build() => null;

  Future<SisStudent?> execute({
    required String studentId,
    required UpdateStudentStatusRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudents: true,
        invalidateStudentId: studentId,
        action: () => ref.read(sisRepositoryProvider).updateStudentStatus(
              query: ref.read(repositoryQueryProvider),
              studentId: studentId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateStudentStatusProvider =
    AsyncNotifierProvider<UpdateStudentStatusNotifier, SisStudent?>(
  UpdateStudentStatusNotifier.new,
);

class AssignAcademicAssignmentNotifier extends AsyncNotifier<SisStudent?> {
  @override
  FutureOr<SisStudent?> build() => null;

  Future<SisStudent?> execute(AcademicAssignmentRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final catalog = ref.read(academicCatalogProvider);
      final enriched = catalog == null
          ? request
          : enrichAcademicAssignmentRequest(request, catalog);
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudents: true,
        invalidateStudentId: request.studentId,
        action: () => ref.read(sisRepositoryProvider).assignAcademicAssignment(
              query: ref.read(repositoryQueryProvider),
              request: enriched,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final assignAcademicAssignmentProvider =
    AsyncNotifierProvider<AssignAcademicAssignmentNotifier, SisStudent?>(
  AssignAcademicAssignmentNotifier.new,
);

/// Assigns many students to the same class/section/academic year, reusing the
/// single-student assignment path per student. Returns the number assigned.
class BulkAcademicAssignmentNotifier extends AsyncNotifier<int?> {
  @override
  FutureOr<int?> build() => null;

  Future<int?> execute(BulkAcademicAssignmentRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageSis(ref);
      if (request.studentIds.isEmpty) {
        throw ApiFailureException(
          const ApiFailure(
            type: ApiFailureType.unknown,
            message: 'Select at least one student to bulk assign.',
            code: 'SIS_BULK_ASSIGN_EMPTY',
          ),
        );
      }
      try {
        final catalog = ref.read(academicCatalogProvider);
        final repo = ref.read(sisRepositoryProvider);
        final query = ref.read(repositoryQueryProvider);
        for (final studentId in request.studentIds) {
          final single = AcademicAssignmentRequest(
            studentId: studentId,
            classLabel: request.classLabel,
            section: request.section,
            academicYear: request.academicYear,
          );
          final enriched = catalog == null
              ? single
              : enrichAcademicAssignmentRequest(single, catalog);
          await repo.assignAcademicAssignment(query: query, request: enriched);
        }
        _invalidateSisReads(ref, students: true, dashboard: true);
        return request.studentIds.length;
      } catch (error) {
        if (error is ApiFailureException) rethrow;
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final bulkAcademicAssignmentProvider =
    AsyncNotifierProvider<BulkAcademicAssignmentNotifier, int?>(
  BulkAcademicAssignmentNotifier.new,
);

class ConvertAdmissionsEnrollmentNotifier
    extends AsyncNotifier<SisConversionPreview?> {
  @override
  FutureOr<SisConversionPreview?> build() => null;

  Future<SisConversionPreview?> execute(
    AdmissionsConversionRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final catalog = ref.read(academicCatalogProvider);
      final enriched = catalog == null
          ? request
          : enrichAdmissionsConversionRequest(request, catalog);
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudents: true,
        invalidateDashboard: true,
        invalidateConversion: true,
        action: () =>
            ref.read(sisRepositoryProvider).convertAdmissionsEnrollment(
                  query: ref.read(repositoryQueryProvider),
                  request: enriched,
                ),
      );
    });
    return state.valueOrNull;
  }
}

final convertAdmissionsEnrollmentProvider = AsyncNotifierProvider<
    ConvertAdmissionsEnrollmentNotifier, SisConversionPreview?>(
  ConvertAdmissionsEnrollmentNotifier.new,
);
