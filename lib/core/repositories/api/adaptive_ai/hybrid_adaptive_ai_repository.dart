// Adaptive AI (P3-AI-2 / W2) — Hybrid wrapper. The Adaptive AI surfaces are
// read-mostly and safe to fail soft: on an API failure the feed/search degrade
// to empty (the deterministic ERP screens still work) rather than throwing into
// the dashboard. Feedback is best-effort (a lost accept/dismiss only skips a
// learning tick). Mirrors the copilot Hybrid pass-through shape, with the
// fail-soft fallback the read-cache-style repos use.

import 'package:flutter/foundation.dart';

import '../../../../features/adaptive_ai/adaptive_ai_models.dart';
import '../../../../features/adaptive_ai/adaptive_lifecycle.dart';
import '../../interfaces/adaptive_ai_repository.dart';
import '../../repository_query.dart';
import 'api_adaptive_ai_repository.dart';

class HybridAdaptiveAiRepository implements AdaptiveAiRepository {
  HybridAdaptiveAiRepository({required ApiAdaptiveAiRepository api}) : _api = api;

  final ApiAdaptiveAiRepository _api;

  // P2-2: the surfaces fail SOFT (a backend blip degrades to empty rather than
  // breaking the dashboard), but the failure must not be INVISIBLE — log it so a
  // real outage is distinguishable from "this persona has no items" in dev/CI/
  // profile logs (matches the sibling Hybrid repos' debugPrint convention).
  void _logFailure(String op, Object error, StackTrace stack) {
    if (!kReleaseMode) {
      debugPrint('AdaptiveAI hybrid: $op failed, degrading soft: $error');
    }
    assert(() {
      debugPrintStack(stackTrace: stack, label: 'AdaptiveAI.$op');
      return true;
    }());
  }

  @override
  Future<AdaptiveFeed> getPriorityFeed({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  }) async {
    try {
      return await _api.getPriorityFeed(query: query, persona: persona, limit: limit);
    } catch (error, stack) {
      _logFailure('getPriorityFeed', error, stack);
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
    } catch (error, stack) {
      _logFailure('getRecommendations', error, stack);
      return AdaptiveFeed.empty(persona);
    }
  }

  @override
  Future<void> sendRecommendationFeedback({
    required RepositoryQuery query,
    required String itemKey,
    required String itemType,
    AdaptiveFeedbackAction? action,
    AdaptiveLifecycleWrite? lifecycle,
  }) async {
    try {
      await _api.sendRecommendationFeedback(
        query: query,
        itemKey: itemKey,
        itemType: itemType,
        action: action,
        lifecycle: lifecycle,
      );
    } catch (error, stack) {
      _logFailure('sendRecommendationFeedback', error, stack);
      // A lost LEARNING tick is non-critical — the ranker just misses one
      // signal. A lost LIFECYCLE write is not: the user watched the card leave
      // the screen, so swallowing the failure would leave them believing an
      // item is snoozed when the server never recorded it, and it would silently
      // return. Rethrow so the caller can undo the optimistic removal and say so.
      if (lifecycle != null) rethrow;
    }
  }

  @override
  Future<List<AdaptiveQuickAction>> getQuickActions({
    required RepositoryQuery query,
    required String persona,
  }) async {
    try {
      return await _api.getQuickActions(query: query, persona: persona);
    } catch (error, stack) {
      _logFailure('getQuickActions', error, stack);
      return const [];
    }
  }

  @override
  Future<UniversalSearchResult> universalSearch({
    required RepositoryQuery query,
    required String term,
    int? limit,
    int? offset,
  }) async {
    try {
      return await _api.universalSearch(query: query, term: term, limit: limit, offset: offset);
    } catch (error, stack) {
      _logFailure('universalSearch', error, stack);
      return UniversalSearchResult.empty(term);
    }
  }
}
