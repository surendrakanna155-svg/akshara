import 'package:flutter/material.dart';

import '../../../features/sis/sis_models.dart';
import '../interfaces/sis_repository.dart';

class MockSisRepository implements SisRepository {
  @override
  SisDashboardData getDashboard() {
    return const SisDashboardData(
      kpis: [
        SisKpi(
          id: 'total_students',
          value: '1,248',
          label: 'Total Students',
          icon: Icons.groups_outlined,
          accentName: 'primary',
        ),
        SisKpi(
          id: 'new_admissions',
          value: '36',
          label: 'New Admissions (MTD)',
          icon: Icons.person_add_outlined,
          accentName: 'success',
          detail: '+8 this week',
        ),
        SisKpi(
          id: 'active_students',
          value: '1,198',
          label: 'Active Students',
          icon: Icons.verified_outlined,
          accentName: 'success',
        ),
        SisKpi(
          id: 'pending_conversion',
          value: '2',
          label: 'Pending Conversion',
          icon: Icons.swap_horiz_outlined,
          accentName: 'warning',
        ),
        SisKpi(
          id: 'classes',
          value: '14',
          label: 'Classes',
          icon: Icons.class_outlined,
          accentName: 'neutral',
        ),
        SisKpi(
          id: 'sections',
          value: '42',
          label: 'Sections',
          icon: Icons.grid_view_outlined,
          accentName: 'neutral',
        ),
      ],
      classDistribution: [
        DistributionSegment(label: 'Primary (1–5)', count: 412, percent: 33),
        DistributionSegment(label: 'Middle (6–8)', count: 378, percent: 30),
        DistributionSegment(label: 'Secondary (9–10)', count: 298, percent: 24),
        DistributionSegment(label: 'Senior (11–12)', count: 160, percent: 13),
      ],
      genderDistribution: [
        DistributionSegment(label: 'Male', count: 648, percent: 52),
        DistributionSegment(label: 'Female', count: 592, percent: 47),
        DistributionSegment(label: 'Other', count: 8, percent: 1),
      ],
      recentEnrollments: [
        RecentEnrollment(
          id: 'enr_r1',
          studentName: 'Arjun Patel',
          admissionNumber: 'ADM-2026-0138',
          classLabel: '10',
          section: 'A',
          enrolledAt: 'Today',
          status: SisStudentStatus.active,
        ),
        RecentEnrollment(
          id: 'enr_r2',
          studentName: 'Emma Thomas',
          admissionNumber: 'ADM-2026-0135',
          classLabel: '7',
          section: 'A',
          enrolledAt: 'Yesterday',
          status: SisStudentStatus.active,
        ),
        RecentEnrollment(
          id: 'enr_r3',
          studentName: 'Ananya Reddy',
          admissionNumber: 'ADM-2026-0142',
          classLabel: '5',
          section: 'A',
          enrolledAt: 'Pending',
          status: SisStudentStatus.prospect,
        ),
      ],
      aiInsight:
          'Class 5-A has 3 pending admissions conversions. Complete SIS registration before fee assignment to avoid billing delays.',
    );
  }

  @override
  List<SisStudent> getStudents() => const [
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

  @override
  List<String> getClassOptions() =>
      const ['Nursery', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];

  @override
  List<String> getSectionOptions() => const ['A', 'B', 'C', 'D'];

  @override
  List<String> getAcademicYearOptions() => const ['2026–27', '2025–26', '2024–25'];
}
