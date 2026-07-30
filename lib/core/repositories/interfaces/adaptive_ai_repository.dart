// Adaptive AI (P3-AI-2 / W2) — repository contract for the backend Adaptive
// Intelligence surfaces. All methods are tenant-scoped via RepositoryQuery and
// RBAC-enforced server-side (the client never widens scope). Deterministic /
// zero-token except a copilot-tier quick action, which routes to the governed
// copilot elsewhere.

import '../../../features/adaptive_ai/adaptive_ai_models.dart';
import '../../../features/adaptive_ai/adaptive_lifecycle.dart';
import '../repository_query.dart';

abstract class AdaptiveAiRepository {
  /// The per-persona priority feed (typed items + explainable scores, no action).
  Future<AdaptiveFeed> getPriorityFeed({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  });

  /// The recommendation feed (priority items + pre-staged one-click actions).
  Future<AdaptiveFeed> getRecommendations({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  });

  /// Record feedback and/or a lifecycle change on a recommendation.
  ///
  /// [action] drives the learning loop (accept/dismiss/suppress reweights the
  /// item TYPE). [lifecycle] drives the Living Dashboard queue for this ONE item
  /// (acknowledge/snooze/complete). They are separable because snoozing means
  /// "not now", not "this was a bad suggestion" — sending a learning signal for
  /// it would wrongly down-weight every item of that type.
  ///
  /// At least one must be supplied; the route returns 422 for a body with
  /// neither.
  Future<void> sendRecommendationFeedback({
    required RepositoryQuery query,
    required String itemKey,
    required String itemType,
    AdaptiveFeedbackAction? action,
    AdaptiveLifecycleWrite? lifecycle,
    bool? pinned,
  });

  /// The RBAC-filtered quick actions for a persona (action-first surface).
  Future<List<AdaptiveQuickAction>> getQuickActions({
    required RepositoryQuery query,
    required String persona,
  });

  /// Universal School Search — deterministic, RBAC-scoped entity resolver.
  /// `offset` pages through a category's matches (default 0) — used by the
  /// "Show more" per-category pagination.
  Future<UniversalSearchResult> universalSearch({
    required RepositoryQuery query,
    required String term,
    int? limit,
    int? offset,
  });
}
