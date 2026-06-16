import '../../../features/alumni/alumni_models.dart';
import '../../../features/sis/sis_models.dart';

/// Mutable alumni graduates produced when SIS marks a student as alumni.
final class MockAlumniWriteStore {
  MockAlumniWriteStore._();

  static final MockAlumniWriteStore instance = MockAlumniWriteStore._();

  final List<AlumniRecord> graduates = [];
  int _sequence = 100;

  void reset() {
    graduates.clear();
    _sequence = 100;
  }

  bool hasGraduateForSisStudent(String sisStudentId) {
    return graduates.any((record) => record.sisStudentId == sisStudentId);
  }

  AlumniRecord onboardFromSisStudent(SisStudent student) {
    final existing = graduates
        .where((record) => record.sisStudentId == student.id)
        .toList(growable: false);
    if (existing.isNotEmpty) {
      return existing.first;
    }

    final email = student.email.trim().isEmpty
        ? '${student.studentName.toLowerCase().replaceAll(' ', '.')}@alumni.akshara.edu'
        : student.email;

    final record = AlumniRecord(
      id: 'ALM-${++_sequence}',
      name: student.studentName,
      batchYear: DateTime.now().year.toString(),
      program: 'Class ${student.classLabel} — ${student.section}',
      currentRole: 'Graduate — profile pending',
      city: '—',
      email: email,
      phone: student.phone.trim().isEmpty ? '—' : student.phone,
      engagementStatus: AlumniEngagementStatus.pending,
      sisStudentId: student.id,
      totalDonated: '—',
      lastEventAttended: '—',
    );
    graduates.insert(0, record);
    return record;
  }
}
