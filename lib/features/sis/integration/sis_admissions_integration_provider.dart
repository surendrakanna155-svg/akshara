import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/environment_provider.dart';
import '../../../core/repositories/repository_config.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../admissions/admissions_models.dart';
import '../../admissions/enrollment/admissions_enrollment_records_provider.dart';
import '../registry/sis_registry_provider.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';
import '../sis_mutations_provider.dart';
import '../sis_requests.dart';

final sisAdmissionsConversionLoadingProvider = StateProvider<bool>(
  (ref) => false,
);
final sisAdmissionsConversionErrorProvider = StateProvider<bool>(
  (ref) => false,
);
final sisSelectedEnrollmentIdProvider = StateProvider<String?>((ref) => null);

final sisAdmissionsConversionFutureProvider =
    FutureProvider<SisAdmissionsConversionData>((ref) async {
  return ref.read(sisRepositoryProvider).getAdmissionsConversion(
        query: ref.watch(repositoryQueryProvider),
      );
});

final sisAdmissionsConversionViewStateProvider =
    Provider<SisViewState<SisAdmissionsConversionData>>((ref) {
  return resolveSisAsync(
    ref.watch(sisAdmissionsConversionFutureProvider),
    forceLoading: ref.watch(sisAdmissionsConversionLoadingProvider),
    forceError: ref.watch(sisAdmissionsConversionErrorProvider),
    isDataEmpty: (data) => data.queue.isEmpty,
  );
});

final sisEnrollmentQueueProvider = Provider<List<SisEnrollmentQueueItem>>(
  (ref) {
    final enrollments = ref.watch(admissionsPendingEnrollmentsProvider);
    return [
      for (final enrollment in enrollments)
        SisEnrollmentQueueItem(
          enrollment: enrollment,
          effectiveStatus: enrollment.conversionStatus,
        ),
    ];
  },
);

final sisPendingEnrollmentsProvider = Provider<List<SisEnrollmentQueueItem>>(
  (ref) {
    final queue = ref.watch(sisEnrollmentQueueProvider);
    return queue
        .where(
          (item) =>
              item.effectiveStatus == EnrollmentConversionStatus.pending,
        )
        .toList(growable: false);
  },
);

/// Generates admission number for a pending enrollment conversion.
String generateAdmissionNumber(String enrollmentId) {
  final suffix = enrollmentId.replaceAll('enr_', '').padLeft(4, '0');
  return 'ADM-2026-$suffix';
}

/// Builds SIS student id from enrollment.
String generateSisStudentId(String enrollmentId) {
  final suffix = enrollmentId.replaceAll('enr_', '');
  return 'SIS-STU-104${suffix.padLeft(2, '0')}';
}

/// Converts enrollment to SIS student record and updates admissions status.
Future<SisConversionPreview?> completeSisEnrollmentConversion(
  WidgetRef ref, {
  required String enrollmentId,
  required SisConversionPreview preview,
}) async {
  final apiEnabled =
      ref.read(enableApiModeProvider) && ref.read(sisApiEnabledProvider);
  if (apiEnabled) {
    return ref.read(convertAdmissionsEnrollmentProvider.notifier).execute(
          AdmissionsConversionRequest(
            enrollmentId: enrollmentId,
            classLabel: preview.classLabel,
            section: preview.section,
            academicYear: preview.academicYear,
          ),
        );
  }

  ref.read(enrollmentConversionOverridesProvider.notifier).update(
        (state) => {...state, enrollmentId: EnrollmentConversionStatus.converted},
      );
  ref.read(enrollmentConvertedStudentIdsProvider.notifier).update(
        (state) => {...state, enrollmentId: preview.studentId},
      );

  final result = await ref.read(sisRepositoryProvider).convertAdmissionsEnrollment(
        query: ref.read(repositoryQueryProvider),
        request: AdmissionsConversionRequest(
          enrollmentId: enrollmentId,
          classLabel: preview.classLabel,
          section: preview.section,
          academicYear: preview.academicYear,
        ),
      );

  ref.read(sisConvertedStudentsProvider.notifier).update(
        (state) => [...state, result],
      );
  ref.invalidate(sisStudentsFutureProvider);
  return result;
}

/// Tracks students created via admissions conversion (mock append).
final sisConvertedStudentsProvider =
    StateProvider<List<SisConversionPreview>>((ref) => []);
