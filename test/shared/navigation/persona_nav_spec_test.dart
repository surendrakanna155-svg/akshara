import 'package:akshara_erp/features/parent/shell/parent_shell.dart';
import 'package:akshara_erp/features/student/shell/student_shell.dart';
import 'package:akshara_erp/features/teacher/shell/teacher_shell.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/shared/navigation/persona_nav.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX Batch 2 — Navigation Simplification. The persona shells must keep ≤4
/// primary tabs (the 5th slot is always "More") and every secondary screen must
/// have a real entry point via the More sheet rather than being silently folded
/// into Home.
void main() {
  final specs = <String, PersonaNavSpec>{
    'parent': ParentShell.navSpec,
    'teacher': TeacherShell.navSpec,
    'student': StudentShell.navSpec,
  };

  group('every persona nav spec', () {
    specs.forEach((persona, spec) {
      test('$persona keeps <=4 primary tabs (5th slot stays "More")', () {
        expect(spec.primary.length, inInclusiveRange(1, 4));
      });

      test('$persona exposes its secondary screens via the More sheet', () {
        expect(spec.more, isNotEmpty);
      });

      test('$persona has no duplicate routes across primary + more', () {
        final routes = [
          ...spec.primary.map((d) => d.route),
          ...spec.more.map((d) => d.route),
        ];
        expect(routes.toSet().length, routes.length);
      });

      test('$persona: each primary route lights its own tab only', () {
        for (var i = 0; i < spec.primary.length; i++) {
          final route = spec.primary[i].route;
          final lit = [
            for (var j = 0; j < spec.primary.length; j++)
              if (spec.primary[j].matches(route)) j,
          ];
          expect(lit, [i], reason: '$route should light only tab $i');
        }
      });

      test('$persona: every More route lights the More tab, not a primary tab',
          () {
        for (final more in spec.more) {
          final litPrimary =
              spec.primary.where((d) => d.matches(more.route)).toList();
          expect(litPrimary, isEmpty,
              reason: '${more.route} must fall through to the More tab');
        }
      });
    });
  });

  group('owner decisions', () {
    test('parent promotes Messages to a primary tab', () {
      final labels = ParentShell.navSpec.primary.map((d) => d.label).toList();
      expect(labels, contains('Messages'));
    });

    test('parent un-buries Notices/Leave/Transport/PTM into the More sheet', () {
      final moreRoutes =
          ParentShell.navSpec.more.map((d) => d.route).toSet();
      expect(
        moreRoutes,
        containsAll(<String>[
          RouteNames.parentNotices,
          RouteNames.parentLeave,
          RouteNames.parentTransport,
          RouteNames.parentPtm,
          RouteNames.parentEvents,
          RouteNames.parentProfile,
        ]),
      );
    });
  });
}
