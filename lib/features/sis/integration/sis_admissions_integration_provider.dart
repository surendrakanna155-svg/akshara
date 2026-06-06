import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admissions/admissions_models.dart';
import '../../admissions/enrollment/admissions_enrollment_records_provider.dart';
import '../sis_models.dart';

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

/// Converts enrollment to SIS student record and updates admissions status.
void completeSisEnrollmentConversion(
  WidgetRef ref, {
  required String enrollmentId,
  required SisConversionPreview preview,
}) {
  ref.read(enrollmentConversionOverridesProvider.notifier).update(
        (state) => {...state, enrollmentId: EnrollmentConversionStatus.converted},
      );
  ref.read(enrollmentConvertedStudentIdsProvider.notifier).update(
        (state) => {...state, enrollmentId: preview.studentId},
      );
  ref.read(sisConvertedStudentsProvider.notifier).update(
        (state) => [...state, preview],
      );
}

/// Tracks students created via admissions conversion (mock append).
final sisConvertedStudentsProvider =
    StateProvider<List<SisConversionPreview>>((ref) => []);
