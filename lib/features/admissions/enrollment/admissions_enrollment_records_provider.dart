import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';

/// Shared conversion status overrides (updated by SIS admissions conversion).
final enrollmentConversionOverridesProvider =
    StateProvider<Map<String, EnrollmentConversionStatus>>((ref) => {});

/// Generated SIS student ids keyed by enrollment id after conversion.
final enrollmentConvertedStudentIdsProvider =
    StateProvider<Map<String, String>>((ref) => {});

final admissionsPendingEnrollmentsFutureProvider =
    FutureProvider<List<PendingEnrollmentRecord>>((ref) async {
  final overrides = ref.watch(enrollmentConversionOverridesProvider);
  final studentIds = ref.watch(enrollmentConvertedStudentIdsProvider);
  final enrollments = await ref
      .read(admissionsRepositoryProvider)
      .getPendingEnrollments(query: ref.watch(repositoryQueryProvider));
  return enrollments
      .map((record) {
        final status = overrides[record.id] ?? record.conversionStatus;
        final previewId = studentIds[record.id] ?? record.previewStudentId;
        return PendingEnrollmentRecord(
          id: record.id,
          studentName: record.studentName,
          applicationId: record.applicationId,
          seekingClass: record.seekingClass,
          section: record.section,
          academicYear: record.academicYear,
          guardianName: record.guardianName,
          phone: record.phone,
          submittedAt: record.submittedAt,
          conversionStatus: status,
          generatedAdmissionNumber: record.generatedAdmissionNumber,
          previewStudentId: previewId,
          gender: record.gender,
          dateOfBirth: record.dateOfBirth,
        );
      })
      .toList(growable: false);
});

final admissionsPendingEnrollmentsProvider =
    Provider<List<PendingEnrollmentRecord>>((ref) {
  return watchRepositoryFuture(
        ref,
        ref.watch(admissionsPendingEnrollmentsFutureProvider),
        manualLoading: false,
        manualError: false,
        manualEmpty: false,
      ) ??
      const [];
});

final admissionsPendingEnrollmentsViewStateProvider =
    Provider<AdmissionsViewState<List<PendingEnrollmentRecord>>>((ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsPendingEnrollmentsFutureProvider),
    isDataEmpty: (records) => records.isEmpty,
  );
});
