import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_config.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../integration/sis_finance_integration_provider.dart';
import '../registry/sis_registry_provider.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';

final sisProfileLoadingProvider = StateProvider<bool>((ref) => false);
final sisProfileErrorProvider = StateProvider<bool>((ref) => false);

final sisStudentProfileFutureProvider =
    FutureProvider.family<SisStudentProfile, String>((ref, studentId) async {
  return ref.read(sisRepositoryProvider).getStudentProfile(
        query: ref.watch(repositoryQueryProvider),
        studentId: studentId,
      );
});

final sisStudentProfileViewStateProvider =
    Provider.family<SisViewState<SisStudentProfile>, String>((ref, studentId) {
  return resolveSisAsync(
    ref.watch(sisStudentProfileFutureProvider(studentId)),
    forceLoading: ref.watch(sisProfileLoadingProvider),
    forceError: ref.watch(sisProfileErrorProvider),
  );
});

final sisStudentProfileProvider =
    Provider.family<SisStudentProfile?, String>((ref, studentId) {
  if (isModuleApiEnabled(ref, sisApiEnabledProvider)) {
    return ref.watch(sisStudentProfileViewStateProvider(studentId)).data;
  }

  if (ref.watch(sisProfileLoadingProvider)) return null;
  if (ref.watch(sisProfileErrorProvider)) return null;

  final students = ref.watch(sisStudentsProvider);
  SisStudent? student;
  for (final s in students) {
    if (s.id == studentId) {
      student = s;
      break;
    }
  }
  if (student == null) return null;

  final feeAccount = ref.watch(
    sisFeeAccountForAdmissionProvider(student.admissionNumber),
  );

  return _buildProfile(student, feeAccount);
});

SisStudentProfile _buildProfile(
  SisStudent student,
  SisFeeAccountSummary? feeAccount,
) {
  return SisStudentProfile(
    student: student,
    parent: SisParentDetails(
      guardianName: student.guardianName,
      relationship: 'Guardian',
      phone: student.phone,
      email: student.email,
      address: 'Hyderabad, Telangana',
    ),
    academicHistory: [
      SisAcademicHistoryEntry(
        academicYear: student.academicYear,
        classLabel: student.classLabel,
        section: student.section,
        result: 'Enrolled',
      ),
      const SisAcademicHistoryEntry(
        academicYear: '2025–26',
        classLabel: 'Previous',
        section: '—',
        result: 'Promoted',
      ),
    ],
    feeAccount: feeAccount,
    attendance: const SisAttendanceSummary(
      presentPercent: '94%',
      absentDays: 4,
      lateDays: 2,
      periodLabel: 'This term',
    ),
    documents: const [
      SisDocumentSummary(
        type: 'Birth Certificate',
        status: 'Verified',
        uploadedAt: 'Jan 2026',
      ),
      SisDocumentSummary(
        type: 'Aadhaar',
        status: 'Verified',
        uploadedAt: 'Jan 2026',
      ),
      SisDocumentSummary(
        type: 'Transfer Certificate',
        status: 'Pending',
        uploadedAt: '—',
      ),
    ],
    timeline: [
      SisTimelineEvent(
        dateLabel: student.enrolledAt,
        title: 'Enrolled in SIS',
        detail:
            '${student.classLabel}-${student.section} · ${student.academicYear}',
      ),
      const SisTimelineEvent(
        dateLabel: 'Dec 2025',
        title: 'Admission approved',
        detail: 'AD-07 approval completed',
      ),
      const SisTimelineEvent(
        dateLabel: 'Nov 2025',
        title: 'Application submitted',
        detail: 'AD-03 application received',
      ),
    ],
  );
}
