// Adaptive AI (P3-AI-2 / W2) — Hybrid wrapper. The Adaptive AI surfaces are
// read-mostly and safe to fail soft: on an API failure the feed/search degrade
// to empty (the deterministic ERP screens still work) rather than throwing into
// the dashboard. Feedback is best-effort (a lost accept/dismiss only skips a
// learning tick). Mirrors the copilot Hybrid pass-through shape, with the
// fail-soft fallback the read-cache-style repos use.

import 'package:flutter/foundation.dart';

import '../../../../features/adaptive_ai/adaptive_ai_models.dart';
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
    debugPrint('AdaptiveAI hybrid: $op failed, degrading soft: $error');
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
    required AdaptiveFeedbackAction action,
  }) async {
    try {
      await _api.sendRecommendationFeedback(
        query: query,
        itemKey: itemKey,
        itemType: itemType,
        action: action,
      );
    } catch (error, stack) {
      // Best-effort learning — a lost tick is non-critical, but still observable.
      _logFailure('sendRecommendationFeedback', error, stack);
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
