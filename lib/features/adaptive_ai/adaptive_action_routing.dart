// Living Dashboard — one place that turns a recommendation's deep link into a
// real route.
//
// WHY THIS EXISTS
// ---------------
// This logic was previously duplicated five times: one pure, tested function for
// the principal (`management_adaptive_action_routing.dart`) and four ad-hoc
// ternary chains inlined in the director, teacher, parent and student dashboard
// files. They had already drifted — the principal's handled ops worklists and
// approvals, the director's understood three prefixes, the student's two — so
// the same backend item could navigate somewhere sensible for one persona and
// to a dashboard root for another, with no test anywhere to notice.
//
// The engine emits ONE `deepLink` per item, so it deserves ONE resolver.
//
// CONTRACT
//   · Pure and total: every (persona, link) pair returns a real route constant.
//     A caller must never have to handle null, and an unknown link must land the
//     user somewhere useful rather than nowhere.
//   · Persona-scoped: the same `/finance/...` link means the recovery queue to a
//     principal and the revenue report to a director. Routing is per-persona
//     because the SCREENS are per-persona, not because the item differs.
//   · Navigation only. The human acts on the module screen — the AI never
//     executes the underlying action (governance rail, doc 04 §4).

import '../../router/route_names.dart';

/// Resolve a recommendation's logical deep link to a concrete route for
/// [persona]. Falls back to that persona's most useful hub.
String adaptiveActionRoute(String persona, String deepLink) {
  final link = deepLink.trim();
  return switch (persona) {
    'principal' || 'admin' => _principal(link),
    'finance' => _finance(link),
    'director' => _director(link),
    'teacher' => _teacher(link),
    'parent' => _parent(link),
    'student' => _student(link),
    _ => _principal(link),
  };
}

/// Principal / admin — the widest surface: school-level modules plus the W2.7
/// ops worklists. Preserved verbatim from the original pure implementation,
/// which was the only one of the five with tests.
String _principal(String link) {
  // More specific than the generic '/finance' prefix below: the recovery call
  // queue IS the collection follow-up screen, not the finance overview tab.
  if (link.startsWith('/finance/recovery')) return RouteNames.financeDefaulters;
  if (link.startsWith('/finance')) return RouteNames.managementFinance;
  if (link.startsWith('/inventory/stock')) return RouteNames.inventoryStock;
  if (link.startsWith('/transport')) return RouteNames.transportVehicles;
  if (link.startsWith('/hr')) return RouteNames.hrReports;
  if (link.startsWith('/library')) return RouteNames.libraryOverdue;
  if (link.startsWith('/analytics')) return RouteNames.managementAnalytics;
  if (link.startsWith('/timetable')) return RouteNames.managementTimetable;
  if (link.contains('approval')) return RouteNames.managementApprovals;
  return RouteNames.managementIntelligence;
}

/// Finance persona — the ops feed serves it finance worklists only, so every
/// money link goes to the working screen rather than a management overview.
String _finance(String link) {
  if (link.startsWith('/finance/recovery')) return RouteNames.financeDefaulters;
  if (link.startsWith('/finance')) return RouteNames.financeCollections;
  return RouteNames.financeDashboard;
}

/// Director — aggregate only. Per-student items never reach this persona (the
/// generators enforce that by construction), so there is deliberately no
/// student-scoped branch here to keep in sync.
String _director(String link) {
  if (link.startsWith('/finance')) return RouteNames.directorRevenue;
  if (link.contains('complian')) return RouteNames.directorCompliance;
  return RouteNames.directorPortfolio;
}

String _teacher(String link) {
  if (link.startsWith('/teacher/attendance')) return RouteNames.teacherAttendance;
  if (link.startsWith('/teacher/homework')) return RouteNames.teacherHomework;
  if (link.startsWith('/teacher/exams')) return RouteNames.teacherExams;
  return RouteNames.teacherDashboard;
}

String _parent(String link) {
  if (link.startsWith('/parent/fees')) return RouteNames.parentFees;
  if (link.startsWith('/parent/attendance')) return RouteNames.parentAttendance;
  if (link.startsWith('/parent/homework')) return RouteNames.parentHomework;
  return RouteNames.parentDashboard;
}

String _student(String link) {
  if (link.startsWith('/student/attendance')) return RouteNames.studentAttendance;
  if (link.startsWith('/student/homework')) return RouteNames.studentHomework;
  return RouteNames.studentDashboard;
}
