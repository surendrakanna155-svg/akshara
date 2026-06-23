import '../../../features/alumni/alumni_models.dart';
import '../../../features/alumni/alumni_requests.dart';
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

  /// Adds a manually-entered alumnus (e.g. legacy/pre-system graduates that
  /// were never in SIS). Not linked to a SIS student.
  AlumniRecord addManualAlumni(AddAlumniRequest request) {
    final name = request.name.trim();
    if (name.isEmpty) {
      throw StateError('Alumni name is required');
    }

    final record = AlumniRecord(
      id: 'ALM-${++_sequence}',
      name: name,
      batchYear: request.batchYear.trim().isEmpty
          ? DateTime.now().year.toString()
          : request.batchYear.trim(),
      program: request.program.trim().isEmpty ? '—' : request.program.trim(),
      currentRole:
          request.currentRole.trim().isEmpty ? '—' : request.currentRole.trim(),
      city: request.city.trim().isEmpty ? '—' : request.city.trim(),
      email: request.email.trim(),
      phone: request.phone.trim().isEmpty ? '—' : request.phone.trim(),
      engagementStatus: AlumniEngagementStatus.active,
      sisStudentId: '',
      totalDonated: '—',
      lastEventAttended: '—',
    );
    graduates.insert(0, record);
    return record;
  }
}
