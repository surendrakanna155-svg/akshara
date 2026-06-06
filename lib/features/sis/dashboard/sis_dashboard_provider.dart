import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sis_models.dart';

final sisDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final sisDashboardErrorProvider = StateProvider<bool>((ref) => false);
final sisDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final sisDashboardFilterProvider = StateProvider<int>((ref) => 0);

final sisDashboardProvider = Provider<SisDashboardData?>((ref) {
  if (ref.watch(sisDashboardLoadingProvider)) return null;
  if (ref.watch(sisDashboardErrorProvider)) return null;
  if (ref.watch(sisDashboardEmptyProvider)) return null;
  return _mockDashboard();
});

SisDashboardData _mockDashboard() {
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
