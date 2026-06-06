import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sis_models.dart';

final sisRegistryLoadingProvider = StateProvider<bool>((ref) => false);
final sisRegistryErrorProvider = StateProvider<bool>((ref) => false);
final sisRegistryEmptyProvider = StateProvider<bool>((ref) => false);
final sisRegistrySearchProvider = StateProvider<String>((ref) => '');
final sisRegistryFilterProvider = StateProvider<int>((ref) => 0);

final sisStudentsProvider = Provider<List<SisStudent>>((ref) {
  if (ref.watch(sisRegistryLoadingProvider)) return const [];
  if (ref.watch(sisRegistryErrorProvider)) return const [];
  if (ref.watch(sisRegistryEmptyProvider)) return const [];
  return _mockStudents();
});

final sisFilteredStudentsProvider = Provider<List<SisStudent>>((ref) {
  final students = ref.watch(sisStudentsProvider);
  final query = ref.watch(sisRegistrySearchProvider).trim().toLowerCase();
  final filterIndex = ref.watch(sisRegistryFilterProvider);

  var filtered = students;
  filtered = switch (filterIndex) {
    1 => filtered
        .where((s) => s.status == SisStudentStatus.active)
        .toList(),
    2 => filtered
        .where((s) => s.status == SisStudentStatus.prospect)
        .toList(),
    3 => filtered.where((s) => s.classLabel == '10').toList(),
    _ => filtered,
  };

  if (query.isNotEmpty) {
    filtered = filtered
        .where(
          (s) =>
              s.studentName.toLowerCase().contains(query) ||
              s.admissionNumber.toLowerCase().contains(query),
        )
        .toList();
  }

  return filtered;
});

List<SisStudent> _mockStudents() {
  return const [
    SisStudent(
      id: 'SIS-STU-10421',
      studentName: 'Arjun Patel',
      admissionNumber: 'ADM-2026-0138',
      classLabel: '10',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Male',
      dateOfBirth: '14 Jun 2011',
      guardianName: 'Kiran Patel',
      phone: '+91 98765 11111',
      email: 'kiran.patel@email.com',
      enrolledAt: 'Jan 2026',
      feeAccountId: 'acct_1',
    ),
    SisStudent(
      id: 'SIS-STU-10418',
      studentName: 'Emma Thomas',
      admissionNumber: 'ADM-2026-0135',
      classLabel: '7',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Female',
      dateOfBirth: '22 Jan 2014',
      guardianName: 'David Thomas',
      phone: '+91 99887 76655',
      email: 'david.thomas@email.com',
      enrolledAt: 'Jan 2026',
      feeAccountId: 'acct_3',
    ),
    SisStudent(
      id: 'SIS-STU-10415',
      studentName: 'Priya Sharma',
      admissionNumber: 'ADM-2025-0092',
      classLabel: '8',
      section: 'B',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Female',
      dateOfBirth: '03 Sep 2013',
      guardianName: 'Anil Sharma',
      phone: '+91 91234 00092',
      email: 'anil.sharma@email.com',
      enrolledAt: 'Jun 2025',
      feeAccountId: 'acct_4',
    ),
    SisStudent(
      id: 'SIS-STU-10410',
      studentName: 'Rohan Mehta',
      admissionNumber: 'ADM-2025-0114',
      classLabel: '9',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Male',
      dateOfBirth: '18 Nov 2012',
      guardianName: 'Sunita Mehta',
      phone: '+91 90001 11400',
      email: 'sunita.mehta@email.com',
      enrolledAt: 'Jun 2025',
    ),
    SisStudent(
      id: 'SIS-STU-10405',
      studentName: 'Kavya Iyer',
      admissionNumber: 'ADM-2025-0101',
      classLabel: '6',
      section: 'C',
      academicYear: '2026–27',
      status: SisStudentStatus.prospect,
      gender: 'Female',
      dateOfBirth: '07 Apr 2015',
      guardianName: 'Lakshmi Iyer',
      phone: '+91 94440 10101',
      email: 'lakshmi.iyer@email.com',
      enrolledAt: 'Pending',
    ),
  ];
}
