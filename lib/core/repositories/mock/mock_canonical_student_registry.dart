/// Single source of truth for mock student identity across SIS, teacher,
/// parent, student, transport, hostel, and exam personas.
class CanonicalStudentRecord {
  const CanonicalStudentRecord({
    required this.sisStudentId,
    required this.admissionNumber,
    required this.studentName,
    required this.grade,
    required this.section,
    required this.rollNo,
    this.feeAccountId,
    this.guardianName,
    this.parentChildId,
  });

  final String sisStudentId;
  final String admissionNumber;
  final String studentName;
  final String grade;
  final String section;
  final String rollNo;
  final String? feeAccountId;
  final String? guardianName;
  /// Parent-app child selector id when this student is a linked child.
  final String? parentChildId;

  String get classLabel => '$grade-$section';
}

/// Canonical mock students aligned with [MockSisRepository] seed data.
abstract final class MockCanonicalStudentRegistry {
  /// Primary mobile persona student (parent active child + student app).
  static const String primaryMobileStudentId = 'SIS-STU-10430';

  static const List<CanonicalStudentRecord> all = [
    CanonicalStudentRecord(
      sisStudentId: 'SIS-STU-10421',
      admissionNumber: 'ADM-2026-0138',
      studentName: 'Arjun Patel',
      grade: '10',
      section: 'A',
      rollNo: '12',
      feeAccountId: 'acct_1',
      guardianName: 'Kiran Patel',
    ),
    CanonicalStudentRecord(
      sisStudentId: 'SIS-STU-10418',
      admissionNumber: 'ADM-2026-0135',
      studentName: 'Emma Thomas',
      grade: '7',
      section: 'A',
      rollNo: '08',
      feeAccountId: 'acct_3',
      guardianName: 'David Thomas',
    ),
    CanonicalStudentRecord(
      sisStudentId: 'SIS-STU-10415',
      admissionNumber: 'ADM-2025-0092',
      studentName: 'Priya Sharma',
      grade: '8',
      section: 'B',
      rollNo: '14',
      feeAccountId: 'acct_4',
      guardianName: 'Anil Sharma',
    ),
    CanonicalStudentRecord(
      sisStudentId: primaryMobileStudentId,
      admissionNumber: 'ADM-2026-0842',
      studentName: 'Ravi Kumar',
      grade: '8',
      section: 'A',
      rollNo: '01',
      feeAccountId: 'acct_ravi',
      guardianName: 'Suresh Kumar',
      parentChildId: 'child_ravi',
    ),
    CanonicalStudentRecord(
      sisStudentId: 'SIS-STU-10431',
      admissionNumber: 'ADM-2026-0843',
      studentName: 'Ananya Rao',
      grade: '8',
      section: 'A',
      rollNo: '02',
      guardianName: 'Rajesh Rao',
    ),
    CanonicalStudentRecord(
      sisStudentId: 'SIS-STU-10432',
      admissionNumber: 'ADM-2026-0844',
      studentName: 'Karthik Menon',
      grade: '8',
      section: 'A',
      rollNo: '03',
      guardianName: 'Suresh Menon',
    ),
    CanonicalStudentRecord(
      sisStudentId: 'SIS-STU-10433',
      admissionNumber: 'ADM-2026-0845',
      studentName: 'Priya Nair',
      grade: '8',
      section: 'A',
      rollNo: '04',
      guardianName: 'Lakshmi Nair',
    ),
    CanonicalStudentRecord(
      sisStudentId: 'SIS-STU-10434',
      admissionNumber: 'ADM-2026-0846',
      studentName: 'Meera Iyer',
      grade: '8',
      section: 'A',
      rollNo: '06',
      guardianName: 'Anil Iyer',
    ),
    CanonicalStudentRecord(
      sisStudentId: 'SIS-STU-10410',
      admissionNumber: 'ADM-2025-0114',
      studentName: 'Rohan Mehta',
      grade: '9',
      section: 'A',
      rollNo: '05',
      guardianName: 'Sunita Mehta',
    ),
    CanonicalStudentRecord(
      sisStudentId: 'SIS-STU-10405',
      admissionNumber: 'ADM-2025-0101',
      studentName: 'Kavya Iyer',
      grade: '6',
      section: 'C',
      rollNo: '11',
      guardianName: 'Lakshmi Iyer',
    ),
  ];

  static CanonicalStudentRecord get primaryMobileStudent =>
      byId(primaryMobileStudentId)!;

  static CanonicalStudentRecord? byId(String sisStudentId) {
    for (final record in all) {
      if (record.sisStudentId == sisStudentId) return record;
    }
    return null;
  }

  static CanonicalStudentRecord? byAdmissionNumber(String admissionNumber) {
    for (final record in all) {
      if (record.admissionNumber == admissionNumber) return record;
    }
    return null;
  }

  static CanonicalStudentRecord? byParentChildId(String parentChildId) {
    for (final record in all) {
      if (record.parentChildId == parentChildId) return record;
    }
    return null;
  }

  static List<CanonicalStudentRecord> forClass(String grade, String section) {
    return all
        .where((record) => record.grade == grade && record.section == section)
        .toList(growable: false);
  }

  static List<CanonicalStudentRecord> class8A() => forClass('8', 'A');
}
