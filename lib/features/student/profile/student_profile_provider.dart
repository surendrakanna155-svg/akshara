import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_models.dart';

final studentProfileLoadingProvider = StateProvider<bool>((ref) => false);
final studentProfileErrorProvider = StateProvider<bool>((ref) => false);

final studentProfileProvider = Provider<StudentProfileData>((ref) {
  return const StudentProfileData(
    studentName: 'Ravi Kumar',
    classLabel: '8-A',
    rollNo: '08',
    admissionNo: 'AKS-2024-0842',
    dateOfBirth: '14 Mar 2012',
    bloodGroup: 'B+',
    schoolName: 'Akshara International School',
    unreadNotifications: 2,
    parentContacts: [
      ParentContact(
        name: 'Suresh Kumar',
        relation: 'Father',
        phoneLabel: '+91 98765 43210',
        email: 'suresh.kumar@email.com',
      ),
      ParentContact(
        name: 'Lakshmi Kumar',
        relation: 'Mother',
        phoneLabel: '+91 98765 43211',
        email: 'lakshmi.kumar@email.com',
      ),
    ],
    academicSummary: [
      AcademicSummaryItem(label: 'Current term', value: 'Term 2 · 2025-26'),
      AcademicSummaryItem(label: 'Class teacher', value: 'Mrs. Sharma'),
      AcademicSummaryItem(label: 'Attendance', value: '92% this month'),
      AcademicSummaryItem(label: 'Overall grade', value: 'A'),
    ],
  );
});
