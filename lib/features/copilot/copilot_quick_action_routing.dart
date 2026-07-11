// Adaptive AI — P2-1 (audit): a `kind: 'endpoint'` quick action is deterministic
// (tier t1, 0 tokens, doc 10 §7 rule 7) — the client must navigate straight to
// the ERP screen instead of staging a copilot chat prompt for it. This is the
// pure endpoint-target → client-route mapper; `executeCopilotQuickAction`
// (widgets/copilot_ai_quick_actions.dart) calls it and only falls back to the
// copilot when a target is unmapped, so a quick action never dead-ends.

import '../../router/route_names.dart';
import '../adaptive_ai/adaptive_ai_models.dart';

/// Maps a backend Quick Action Registry `endpoint` resolver target
/// (`supabase/functions/_shared/intelligence/quick_actions/quick_action_catalog.ts`)
/// to the closest EXISTING client route. Pure + testable.
///
/// Returns null for a `copilot`-kind resolver, or an `endpoint` target this
/// client has no screen for — either way the caller falls back to opening the
/// governed copilot with the action's label as the prompt.
String? quickActionEndpointRoute(AdaptiveQuickAction action) {
  if (action.resolver.kind != 'endpoint') return null;

  // Query strings (`?persona=principal`) carry no client-route meaning; an
  // entity placeholder (`{studentId}`) can never be substituted from this
  // generic menu (no entity is in scope here) — both are stripped so the
  // match below always lands on the LIST-level screen for that target.
  final path = action.resolver.target.split('?').first;

  if (path.startsWith('/teacher/attendance')) return RouteNames.teacherAttendance;
  if (path.startsWith('/intelligence/exam')) return RouteNames.examIntelligence;
  if (path.startsWith('/intelligence/risk/students')) {
    return RouteNames.studentSuccessIntelligence;
  }
  if (path.startsWith('/intelligence/priorities') ||
      path.startsWith('/intelligence/recommendations')) {
    // Both feeds already render on the principal's dashboard via
    // AdaptivePriorityFeedSection — that IS the deterministic screen.
    return RouteNames.managementDashboard;
  }
  if (path.startsWith('/intelligence/principal/center')) {
    return RouteNames.principalCommand;
  }
  if (path.startsWith('/parent/homework')) return RouteNames.parentHomework;
  if (path.startsWith('/parent/fees')) return RouteNames.parentFees;
  if (path.startsWith('/finance/dashboard')) return RouteNames.financeDashboard;

  return null;
}
