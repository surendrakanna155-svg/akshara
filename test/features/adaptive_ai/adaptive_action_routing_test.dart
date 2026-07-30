// Living Dashboard — the unified deep-link resolver.
//
// Five implementations used to answer this question and had already drifted, so
// the same backend item navigated somewhere useful for one persona and to a
// dashboard root for another. These tests pin the behaviour that matters:
// totality (never a dead end), persona scoping, and the specific-before-generic
// ordering that a hand-written ternary chain gets wrong first.

import 'package:flutter_test/flutter_test.dart';
import 'package:akshara_erp/features/adaptive_ai/adaptive_action_routing.dart';
import 'package:akshara_erp/router/route_names.dart';

void main() {
  group('specific beats generic', () {
    test('the recovery call queue is the follow-up screen, not the finance tab', () {
      expect(
        adaptiveActionRoute('principal', '/finance/recovery/call-queue'),
        RouteNames.financeDefaulters,
      );
      expect(
        adaptiveActionRoute('principal', '/finance/collections'),
        RouteNames.managementFinance,
      );
    });

    test('the same ordering holds for the finance persona', () {
      expect(
        adaptiveActionRoute('finance', '/finance/recovery/ptp'),
        RouteNames.financeDefaulters,
      );
      expect(
        adaptiveActionRoute('finance', '/finance/anything-else'),
        RouteNames.financeCollections,
      );
    });
  });

  group('persona scoping', () {
    test('one finance link resolves differently per persona — by design', () {
      const link = '/finance/overview';
      expect(adaptiveActionRoute('principal', link), RouteNames.managementFinance);
      expect(adaptiveActionRoute('finance', link), RouteNames.financeCollections);
      expect(adaptiveActionRoute('director', link), RouteNames.directorRevenue);
    });

    test('each persona falls back to its OWN hub, never another persona\'s', () {
      expect(adaptiveActionRoute('principal', '/nonsense'), RouteNames.managementIntelligence);
      expect(adaptiveActionRoute('finance', '/nonsense'), RouteNames.financeDashboard);
      expect(adaptiveActionRoute('director', '/nonsense'), RouteNames.directorPortfolio);
      expect(adaptiveActionRoute('teacher', '/nonsense'), RouteNames.teacherDashboard);
      expect(adaptiveActionRoute('parent', '/nonsense'), RouteNames.parentDashboard);
      expect(adaptiveActionRoute('student', '/nonsense'), RouteNames.studentDashboard);
    });

    test('admin shares the principal map (same screens, same permissions)', () {
      expect(
        adaptiveActionRoute('admin', '/hr/expiring-documents'),
        adaptiveActionRoute('principal', '/hr/expiring-documents'),
      );
    });
  });

  group('the ops worklists the principal feed actually emits', () {
    const cases = <String, String>{
      '/finance/recovery': RouteNames.financeDefaulters,
      '/inventory/stock/low': RouteNames.inventoryStock,
      '/transport/documents': RouteNames.transportVehicles,
      '/hr/probation': RouteNames.hrReports,
      '/library/overdue': RouteNames.libraryOverdue,
      '/analytics/risk': RouteNames.managementAnalytics,
      '/timetable/health': RouteNames.managementTimetable,
    };
    test('every ops source lands on its own module screen', () {
      cases.forEach((link, expected) {
        expect(adaptiveActionRoute('principal', link), expected, reason: link);
      });
    });

    test('an approval link is recognised anywhere in the path', () {
      expect(
        adaptiveActionRoute('principal', '/school/approval-centre'),
        RouteNames.managementApprovals,
      );
    });
  });

  group('per-user personas', () {
    test('teacher links', () {
      expect(adaptiveActionRoute('teacher', '/teacher/attendance/6B'), RouteNames.teacherAttendance);
      expect(adaptiveActionRoute('teacher', '/teacher/homework/12'), RouteNames.teacherHomework);
      expect(adaptiveActionRoute('teacher', '/teacher/exams/unit-2'), RouteNames.teacherExams);
    });

    test('parent links', () {
      expect(adaptiveActionRoute('parent', '/parent/fees'), RouteNames.parentFees);
      expect(adaptiveActionRoute('parent', '/parent/attendance'), RouteNames.parentAttendance);
      expect(adaptiveActionRoute('parent', '/parent/homework'), RouteNames.parentHomework);
    });

    test('student links', () {
      expect(adaptiveActionRoute('student', '/student/attendance'), RouteNames.studentAttendance);
      expect(adaptiveActionRoute('student', '/student/homework/9'), RouteNames.studentHomework);
    });

    test('a director never routes to a per-student screen', () {
      // Per-student items are excluded from the director feed by construction
      // (privacy rule in priority_sources.ts). Even if one arrived, routing must
      // not take an org-scope user into a child's record.
      final route = adaptiveActionRoute('director', '/student/attendance/abc');
      expect(route, RouteNames.directorPortfolio);
      expect(route, isNot(RouteNames.studentAttendance));
    });
  });

  group('totality — a caller never has to handle a dead end', () {
    test('empty, whitespace and junk all resolve', () {
      for (final link in ['', '   ', '::::', 'not-a-path', '/']) {
        for (final persona in [
          'principal', 'admin', 'finance', 'director', 'teacher', 'parent', 'student',
        ]) {
          expect(adaptiveActionRoute(persona, link), isNotEmpty, reason: '$persona / "$link"');
        }
      }
    });

    test('an unknown persona degrades to the principal map rather than crashing', () {
      expect(
        adaptiveActionRoute('librarian', '/library/overdue'),
        RouteNames.libraryOverdue,
      );
    });

    test('surrounding whitespace does not defeat prefix matching', () {
      expect(
        adaptiveActionRoute('parent', '  /parent/fees  '),
        RouteNames.parentFees,
      );
    });
  });
}
