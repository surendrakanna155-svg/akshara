// Adaptive AI (P3-AI-2 / W2) — client providers for the backend feed surfaces.
// Deterministic-first: these read the governed backend (RBAC-scoped, zero-token);
// the UI self-hides when a persona has no feed yet (per-user rollout waves).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../router/route_names.dart';
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

/// Universal School Search — deterministic, zero-token, RBAC-scoped entity
/// resolver. Keyed by the (debounced) query; empty for <2 chars. AutoDisposed.
final adaptiveSearchProvider =
    FutureProvider.autoDispose.family<UniversalSearchResult, String>((ref, term) async {
  final q = term.trim();
  if (q.length < 2) return UniversalSearchResult.empty(q);
  final repo = ref.watch(adaptiveAiRepositoryProvider);
  final query = ref.watch(repositoryQueryProvider);
  return repo.universalSearch(query: query, term: q, limit: 6);
});

/// Map a search-result (category, id) to the real ERP record route (decision 8:
/// a selection navigates directly to the record). Null = no known detail route.
///
/// `finance`/`communications`/`classes` have no per-record detail screen yet,
/// so they route to the closest EXISTING list/management screen for that
/// category rather than a dead link.
String? adaptiveSearchRoute(String category, String id) {
  switch (category) {
    case 'students':
      return RouteNames.sisStudentDetail(id);
    case 'staff':
      return RouteNames.hrEmployeeDetail(id);
    case 'admissions':
      return RouteNames.admissionsLeadDetail(id);
    case 'finance':
      return RouteNames.financeFeeAssignment; // invoice management section
    case 'communications':
      return RouteNames.communicationBroadcastAdmin;
    case 'classes':
      return RouteNames.sisAcademicAssignment; // class/section assignment
    default:
      return null;
  }
}

/// Accumulated "Show more" pages for Universal Search, one category at a time,
/// keyed by the search term. A fresh [AdaptiveSearchExtraNotifier] instance is
/// created per term (family + autoDispose), so switching the query resets the
/// accumulated pages for free — no explicit reset needed.
@immutable
class AdaptiveSearchExtraState {
  const AdaptiveSearchExtraState({this.extra = const {}, this.loadingCategory});

  /// Extra pages loaded per category, appended after the base search results.
  final Map<String, List<SearchResultItem>> extra;

  /// The category currently fetching its next page, if any — drives the
  /// "Show more" button's loading/disabled state.
  final String? loadingCategory;

  AdaptiveSearchExtraState _loading(String category) =>
      AdaptiveSearchExtraState(extra: extra, loadingCategory: category);

  AdaptiveSearchExtraState _appended(String category, List<SearchResultItem> page) {
    final next = Map<String, List<SearchResultItem>>.from(extra);
    next[category] = [...(next[category] ?? const []), ...page];
    return AdaptiveSearchExtraState(extra: next);
  }

  AdaptiveSearchExtraState _idle() => AdaptiveSearchExtraState(extra: extra);
}

/// Loads and accumulates additional Universal Search pages, one category at a
/// time, for a fixed search term. Simplest-correct "load more": re-runs the
/// SAME term against the full `/search` endpoint at the category's next
/// offset (the backend re-runs all RBAC-gated category searchers per call at
/// limit 6-8, so re-fetching every group just to page one category is
/// acceptable cost) and keeps only that category's page from the response.
class AdaptiveSearchExtraNotifier extends AutoDisposeFamilyNotifier<AdaptiveSearchExtraState, String> {
  @override
  AdaptiveSearchExtraState build(String term) => const AdaptiveSearchExtraState();

  Future<void> loadMore({required String category, required int nextOffset}) async {
    if (state.loadingCategory != null) return; // one in-flight fetch at a time
    // A term change mid-flight disposes this family instance (autoDispose
    // keyed by term); writing state after disposal throws a framework error.
    // Track disposal and drop the late resolution instead (audit round 4,
    // P3-c).
    var disposed = false;
    ref.onDispose(() => disposed = true);
    state = state._loading(category);
    try {
      final repo = ref.read(adaptiveAiRepositoryProvider);
      final query = ref.read(repositoryQueryProvider);
      final result = await repo.universalSearch(
        query: query,
        term: arg,
        offset: nextOffset,
        limit: 6,
      );
      if (disposed) return;
      SearchGroup? group;
      for (final g in result.groups) {
        if (g.category == category) {
          group = g;
          break;
        }
      }
      state = group == null ? state._idle() : state._appended(category, group.results);
    } catch (_) {
      // Fail soft (same posture as HybridAdaptiveAiRepository): a blip just
      // means "Show more" silently didn't add a page; base results still render.
      if (!disposed) state = state._idle();
    }
  }
}

final adaptiveSearchExtraProvider = NotifierProvider.autoDispose
    .family<AdaptiveSearchExtraNotifier, AdaptiveSearchExtraState, String>(
  AdaptiveSearchExtraNotifier.new,
);

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
