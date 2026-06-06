import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admissions_models.dart';

/// Shared conversion status overrides (updated by SIS admissions conversion).
final enrollmentConversionOverridesProvider =
    StateProvider<Map<String, EnrollmentConversionStatus>>((ref) => {});

/// Generated SIS student ids keyed by enrollment id after conversion.
final enrollmentConvertedStudentIdsProvider =
    StateProvider<Map<String, String>>((ref) => {});

final admissionsPendingEnrollmentsProvider =
    Provider<List<PendingEnrollmentRecord>>((ref) {
  final overrides = ref.watch(enrollmentConversionOverridesProvider);
  final studentIds = ref.watch(enrollmentConvertedStudentIdsProvider);
  return _mockEnrollments()
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

List<PendingEnrollmentRecord> _mockEnrollments() {
  return const [
    PendingEnrollmentRecord(
      id: 'enr_1',
      studentName: 'Ananya Reddy',
      applicationId: 'APP-2208',
      seekingClass: '5',
      section: 'A',
      academicYear: '2026–27',
      guardianName: 'Rajesh Reddy',
      phone: '+91 98765 43210',
      submittedAt: 'Today',
      conversionStatus: EnrollmentConversionStatus.pending,
      gender: 'Female',
      dateOfBirth: '12 Mar 2016',
    ),
    PendingEnrollmentRecord(
      id: 'enr_2',
      studentName: 'Vihaan Sharma',
      applicationId: 'APP-2215',
      seekingClass: '8',
      section: 'B',
      academicYear: '2026–27',
      guardianName: 'Priya Sharma',
      phone: '+91 91234 56780',
      submittedAt: 'Yesterday',
      conversionStatus: EnrollmentConversionStatus.pending,
      gender: 'Male',
      dateOfBirth: '05 Aug 2013',
    ),
    PendingEnrollmentRecord(
      id: 'enr_3',
      studentName: 'Emma Thomas',
      applicationId: 'APP-2175',
      seekingClass: '7',
      section: 'A',
      academicYear: '2026–27',
      guardianName: 'David Thomas',
      phone: '+91 99887 76655',
      submittedAt: '3 days ago',
      conversionStatus: EnrollmentConversionStatus.converted,
      generatedAdmissionNumber: 'ADM-2026-0135',
      previewStudentId: 'SIS-STU-10418',
      gender: 'Female',
      dateOfBirth: '22 Jan 2014',
    ),
  ];
}
