// Adaptive AI (P3-AI-2 / W2) — client providers for the backend feed surfaces.
// Deterministic-first: these read the governed backend (RBAC-scoped, zero-token);
// the UI self-hides when a persona has no feed yet (per-user rollout waves).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import '../copilot/copilot_role_intelligence.dart';
import 'adaptive_ai_models.dart';

/// Map a client persona role to the backend feed persona string. The W2.0 feed
/// route serves the school-operational/aggregate personas today; per-user
/// personas (teacher/parent/student) return an empty feed until their rollout
/// wave, and the UI self-hides — no broken surface.
String adaptiveBackendPersona(CopilotPersonaRole role) {
  switch (role) {
    case CopilotPersonaRole.principal:
      return 'principal';
    case CopilotPersonaRole.directorCorrespondent:
      return 'director';
    case CopilotPersonaRole.finance:
      return 'finance';
    case CopilotPersonaRole.platformOwner:
    case CopilotPersonaRole.organizationOwner:
    case CopilotPersonaRole.academicCoordinator:
    case CopilotPersonaRole.hr:
      return 'admin';
    case CopilotPersonaRole.teacher:
      return 'teacher';
    case CopilotPersonaRole.parent:
      return 'parent';
    case CopilotPersonaRole.student:
      return 'student';
  }
}

/// The recommendation feed (priority items + pre-staged actions) for a persona.
/// Keyed by persona so multiple surfaces share one fetch; auto-disposed.
final adaptiveRecommendationsProvider =
    FutureProvider.autoDispose.family<AdaptiveFeed, String>((ref, persona) async {
  final repo = ref.watch(adaptiveAiRepositoryProvider);
  final query = ref.watch(repositoryQueryProvider);
  return repo.getRecommendations(query: query, persona: persona, limit: 6);
});

/// The raw priority feed (no actions), for surfaces that only rank/triage.
final adaptivePriorityFeedProvider =
    FutureProvider.autoDispose.family<AdaptiveFeed, String>((ref, persona) async {
  final repo = ref.watch(adaptiveAiRepositoryProvider);
  final query = ref.watch(repositoryQueryProvider);
  return repo.getPriorityFeed(query: query, persona: persona, limit: 6);
});

/// The RBAC-filtered quick actions for a persona (action-first surface).
final adaptiveQuickActionsProvider =
    FutureProvider.autoDispose.family<List<AdaptiveQuickAction>, String>((ref, persona) async {
  final repo = ref.watch(adaptiveAiRepositoryProvider);
  final query = ref.watch(repositoryQueryProvider);
  return repo.getQuickActions(query: query, persona: persona);
});

/// Record accept/dismiss/suppress feedback, then refresh the persona's feed.
Future<void> recordAdaptiveFeedback(
  WidgetRef ref, {
  required String persona,
  required AdaptivePriorityItem item,
  required AdaptiveFeedbackAction action,
}) async {
  final repo = ref.read(adaptiveAiRepositoryProvider);
  await repo.sendRecommendationFeedback(
    query: ref.read(repositoryQueryProvider),
    itemKey: item.itemKey,
    itemType: item.type,
    action: action,
  );
  ref.invalidate(adaptiveRecommendationsProvider(persona));
  ref.invalidate(adaptivePriorityFeedProvider(persona));
}
