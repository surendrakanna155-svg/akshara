import '../adaptive_ai/adaptive_action_routing.dart';

/// Maps an Adaptive AI recommendation's (logical) deepLink — including the
/// W2.7 ops-module worklists (`recommendation_actions.ts`) — to the principal's
/// closest EXISTING management/module route. Pure; the caller performs the
/// actual `context.go(...)`. Unknown deep links fall back to the management
/// intelligence hub — the AI only ever navigated, it never executed the
/// underlying action.
///
/// Living Dashboard Phase 4: the implementation moved into the single shared
/// resolver at `adaptive_ai/adaptive_action_routing.dart`, which now serves
/// every persona. Five copies of this logic existed and had already drifted;
/// this was the only one with tests, so it survives as a thin delegate and its
/// existing suite becomes the regression proof that consolidating them did not
/// change principal behaviour.
///
/// Prefer `adaptiveActionRoute('principal', link)` in new code.
String managementAdaptiveActionRoute(String deepLink) =>
    adaptiveActionRoute('principal', deepLink);
