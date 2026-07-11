import 'package:akshara_erp/features/adaptive_ai/adaptive_ai_models.dart';
import 'package:akshara_erp/features/copilot/copilot_quick_action_routing.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

AdaptiveQuickAction _endpointAction(String target, {String? requiresEntity}) {
  return AdaptiveQuickAction(
    id: 'x',
    label: 'x',
    tier: 't1',
    requiresEntity: requiresEntity,
    resolver: QuickActionResolver(kind: 'endpoint', target: target),
  );
}

AdaptiveQuickAction _copilotAction() {
  return const AdaptiveQuickAction(
    id: 'x',
    label: 'x',
    tier: 't3',
    resolver: QuickActionResolver(kind: 'copilot', target: 'academic', prompt: 'Explain.'),
  );
}

void main() {
  group('quickActionEndpointRoute — every backend catalog endpoint target', () {
    // supabase/functions/_shared/intelligence/quick_actions/quick_action_catalog.ts
    // — every `kind: 'endpoint'` entry, verbatim target string.
    test('principal_today_priorities -> management dashboard (feed lives there)', () {
      expect(
        quickActionEndpointRoute(_endpointAction('/intelligence/priorities?persona=principal')),
        RouteNames.managementDashboard,
      );
    });

    test('principal_high_risk_students -> student success intelligence', () {
      expect(
        quickActionEndpointRoute(_endpointAction('/intelligence/risk/students?riskLevel=high')),
        RouteNames.studentSuccessIntelligence,
      );
    });

    test('principal_fee_collection_summary -> finance dashboard', () {
      expect(
        quickActionEndpointRoute(_endpointAction('/finance/dashboard')),
        RouteNames.financeDashboard,
      );
    });

    test('principal_school_health -> principal command', () {
      expect(
        quickActionEndpointRoute(_endpointAction('/intelligence/principal/center')),
        RouteNames.principalCommand,
      );
    });

    test('principal_recommendations -> management dashboard (feed lives there)', () {
      expect(
        quickActionEndpointRoute(_endpointAction('/intelligence/recommendations?persona=principal')),
        RouteNames.managementDashboard,
      );
    });

    test('teacher_class_attendance_summary -> teacher attendance', () {
      expect(
        quickActionEndpointRoute(_endpointAction('/teacher/attendance/classes')),
        RouteNames.teacherAttendance,
      );
    });

    test('teacher_weak_chapters -> exam intelligence', () {
      expect(
        quickActionEndpointRoute(_endpointAction('/intelligence/exam/weak-chapters')),
        RouteNames.examIntelligence,
      );
    });

    test('teacher_why_student_at_risk (requiresEntity: student, no entity in scope) '
        '-> the LIST-level risk screen, never a broken detail route', () {
      expect(
        quickActionEndpointRoute(
          _endpointAction('/intelligence/risk/students/{studentId}', requiresEntity: 'student'),
        ),
        RouteNames.studentSuccessIntelligence,
      );
    });

    test('parent_homework_summary -> parent homework', () {
      expect(
        quickActionEndpointRoute(_endpointAction('/parent/homework')),
        RouteNames.parentHomework,
      );
    });

    test('parent_fee_reminder_explanation -> parent fees', () {
      expect(
        quickActionEndpointRoute(_endpointAction('/parent/fees')),
        RouteNames.parentFees,
      );
    });
  });

  group('quickActionEndpointRoute — non-endpoint / unmappable targets', () {
    test('a copilot-kind resolver returns null (caller opens the assistant)', () {
      expect(quickActionEndpointRoute(_copilotAction()), isNull);
    });

    test('an unknown endpoint target returns null — documented fallback to copilot, '
        'never a dead tap', () {
      expect(quickActionEndpointRoute(_endpointAction('/analytics/dashboard')), isNull);
      expect(quickActionEndpointRoute(_endpointAction('/some/unmapped/target')), isNull);
    });
  });
}
