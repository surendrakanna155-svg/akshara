// Adaptive AI (P3-AI-2 / W2) — Hybrid wrapper. The Adaptive AI surfaces are
// read-mostly and safe to fail soft: on an API failure the feed/search degrade
// to empty (the deterministic ERP screens still work) rather than throwing into
// the dashboard. Feedback is best-effort (a lost accept/dismiss only skips a
// learning tick). Mirrors the copilot Hybrid pass-through shape, with the
// fail-soft fallback the read-cache-style repos use.

import '../../../../features/adaptive_ai/adaptive_ai_models.dart';
import '../../interfaces/adaptive_ai_repository.dart';
import '../../repository_query.dart';
import 'api_adaptive_ai_repository.dart';

class HybridAdaptiveAiRepository implements AdaptiveAiRepository {
  HybridAdaptiveAiRepository({required ApiAdaptiveAiRepository api}) : _api = api;

  final ApiAdaptiveAiRepository _api;

  @override
  Future<AdaptiveFeed> getPriorityFeed({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  }) async {
    try {
      return await _api.getPriorityFeed(query: query, persona: persona, limit: limit);
    } catch (_) {
      return AdaptiveFeed.empty(persona);
    }
  }

  @override
  Future<AdaptiveFeed> getRecommendations({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  }) async {
    try {
      return await _api.getRecommendations(query: query, persona: persona, limit: limit);
    } catch (_) {
      return AdaptiveFeed.empty(persona);
    }
  }

  @override
  Future<void> sendRecommendationFeedback({
    required RepositoryQuery query,
    required String itemKey,
    required String itemType,
    required AdaptiveFeedbackAction action,
  }) async {
    try {
      await _api.sendRecommendationFeedback(
        query: query,
        itemKey: itemKey,
        itemType: itemType,
        action: action,
      );
    } catch (_) {
      // Best-effort learning — a lost tick is non-critical.
    }
  }

  @override
  Future<List<AdaptiveQuickAction>> getQuickActions({
    required RepositoryQuery query,
    required String persona,
  }) async {
    try {
      return await _api.getQuickActions(query: query, persona: persona);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<UniversalSearchResult> universalSearch({
    required RepositoryQuery query,
    required String term,
    int? limit,
  }) async {
    try {
      return await _api.universalSearch(query: query, term: term, limit: limit);
    } catch (_) {
      return UniversalSearchResult.empty(term);
    }
  }
}
