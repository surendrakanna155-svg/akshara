import 'package:flutter/material.dart';

import '../../../router/route_names.dart';

/// Searchable ERP destination for global search overlay.
@immutable
class GlobalSearchEntry {
  const GlobalSearchEntry({
    required this.label,
    required this.route,
    required this.module,
    this.keywords = const [],
  });

  final String label;
  final String route;
  final String module;
  final List<String> keywords;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (label.toLowerCase().contains(q)) return true;
    if (module.toLowerCase().contains(q)) return true;
    for (final keyword in keywords) {
      if (keyword.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

/// Client-side route index for global search (no backend).
abstract final class GlobalSearchRegistry {
  static const entries = <GlobalSearchEntry>[
    GlobalSearchEntry(
      label: 'Management Dashboard',
      route: RouteNames.managementDashboard,
      module: 'Management',
      keywords: ['principal', 'overview', 'health'],
    ),
    GlobalSearchEntry(
      label: 'Analytics & Intelligence',
      route: RouteNames.managementIntelligence,
      module: 'Management',
      keywords: ['risk', 'trends', 'executive'],
    ),
    GlobalSearchEntry(
      label: 'Finance Dashboard',
      route: RouteNames.financeDashboard,
      module: 'Finance',
      keywords: ['fees', 'collection', 'revenue'],
    ),
    GlobalSearchEntry(
      label: 'Fee Defaulters',
      route: RouteNames.financeDefaulters,
      module: 'Finance',
      keywords: ['outstanding', 'dues'],
    ),
    GlobalSearchEntry(
      label: 'Finance Executive Dashboard',
      route: RouteNames.financeExecutiveDashboard,
      module: 'Finance',
      keywords: ['executive', 'health score'],
    ),
    GlobalSearchEntry(
      label: 'Finance Reports',
      route: RouteNames.financeReports,
      module: 'Finance',
      keywords: ['export', 'analytics'],
    ),
    GlobalSearchEntry(
      label: 'Admissions Dashboard',
      route: RouteNames.admissionsDashboard,
      module: 'Admissions',
      keywords: ['leads', 'pipeline'],
    ),
    GlobalSearchEntry(
      label: 'Student Enrollment',
      route: RouteNames.admissionsEnrollment,
      module: 'Admissions',
      keywords: ['register', 'admit', 'form'],
    ),
    GlobalSearchEntry(
      label: 'Admissions Reports',
      route: RouteNames.admissionsReports,
      module: 'Admissions',
      keywords: ['funnel', 'conversion'],
    ),
    GlobalSearchEntry(
      label: 'SIS Student Registry',
      route: RouteNames.sisStudents,
      module: 'SIS',
      keywords: ['students', 'registry', 'search'],
    ),
    GlobalSearchEntry(
      label: 'Academic Assignment',
      route: RouteNames.sisAcademicAssignment,
      module: 'SIS',
      keywords: ['class', 'section'],
    ),
    GlobalSearchEntry(
      label: 'Inventory Dashboard',
      route: RouteNames.inventoryDashboard,
      module: 'Inventory',
      keywords: ['stock', 'procurement'],
    ),
    GlobalSearchEntry(
      label: 'Inventory Reports',
      route: RouteNames.inventoryReports,
      module: 'Inventory',
      keywords: ['analytics', 'trends'],
    ),
    GlobalSearchEntry(
      label: 'Inventory Lifecycle',
      route: RouteNames.inventoryLifecycle,
      module: 'Inventory',
      keywords: ['lifecycle', 'intelligence'],
    ),
    GlobalSearchEntry(
      label: 'Communication Analytics',
      route: RouteNames.communicationAnalytics,
      module: 'Communication',
      keywords: ['messages', 'delivery'],
    ),
    GlobalSearchEntry(
      label: 'Exam Intelligence',
      route: RouteNames.examIntelligence,
      module: 'Intelligence',
      keywords: ['exams', 'results'],
    ),
    GlobalSearchEntry(
      label: 'Student Success Intelligence',
      route: RouteNames.studentSuccessIntelligence,
      module: 'Intelligence',
      keywords: ['at-risk', 'success'],
    ),
    GlobalSearchEntry(
      label: 'Parent Dashboard',
      route: RouteNames.parentDashboard,
      module: 'Parent',
      keywords: ['home', 'child'],
    ),
    GlobalSearchEntry(
      label: 'Teacher Dashboard',
      route: RouteNames.teacherDashboard,
      module: 'Teacher',
      keywords: ['classes', 'attendance'],
    ),
    GlobalSearchEntry(
      label: 'Student Dashboard',
      route: RouteNames.studentDashboard,
      module: 'Student',
      keywords: ['homework', 'exams'],
    ),
  ];

  static List<GlobalSearchEntry> search(String query) {
    return entries.where((entry) => entry.matches(query)).toList();
  }
}
