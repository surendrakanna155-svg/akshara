// Adaptive AI (P3-AI-2 / W2) — client domain models for the backend Adaptive
// Intelligence surfaces: the Priority/Recommendation feed, the Quick Action
// registry, and Universal School Search. Deterministic, backend-driven; the
// client renders what the governed backend computed (RBAC-scoped, zero-token
// except copilot t3). Plain immutable value types — no business logic here.

import 'package:flutter/foundation.dart';

/// The learning signal a user can send on a recommendation (doc 04 §4 / P12).
enum AdaptiveFeedbackAction { accept, dismiss, suppress }

/// A pre-staged one-click action on a recommendation. The human always confirms
/// — AI never executes (governance rail). `deepLink` is a logical route the
/// client maps to a screen; `payload` pre-fills it.
@immutable
class AdaptiveAction {
  const AdaptiveAction({
    required this.label,
    required this.deepLink,
    this.payload = const {},
    this.requiresConfirmation = true,
  });

  final String label;
  final String deepLink;
  final Map<String, dynamic> payload;
  final bool requiresConfirmation;
}

/// The four scoring factors behind a priority score (doc 04 §3.2 —
/// `score = urgency × impact × ageBoost × learnedWeight`), always exposed so
/// the UI can answer "why is this first?" beyond the one-line [reason].
@immutable
class AdaptiveFactorBreakdown {
  const AdaptiveFactorBreakdown({
    required this.urgency,
    required this.impact,
    required this.ageBoost,
    required this.learnedWeight,
  });

  final double urgency;
  final double impact;
  final double ageBoost;
  final double learnedWeight;
}

/// A scored, explainable priority item. `action` is present on recommendations,
/// null on the raw priority feed.
@immutable
class AdaptivePriorityItem {
  const AdaptivePriorityItem({
    required this.itemKey,
    required this.type,
    required this.title,
    required this.detail,
    required this.score,
    required this.reason,
    this.action,
    this.factorBreakdown,
  });

  final String itemKey;

  /// approval | deadline | exception | follow_up | opportunity
  final String type;
  final String title;
  final String detail;

  /// 0–100 display score (higher = more urgent).
  final int score;

  /// Human "why is this first?" one-liner (explainability rail).
  final String reason;
  final AdaptiveAction? action;

  /// The raw factor multipliers behind [score] — null when the source
  /// (envelope/mock) didn't carry one; the UI hides the expandable detail then.
  final AdaptiveFactorBreakdown? factorBreakdown;

  bool get isCritical => score >= 75;
}

/// A per-persona feed (priorities or recommendations).
@immutable
class AdaptiveFeed {
  const AdaptiveFeed({
    required this.persona,
    required this.items,
    this.criticalCount = 0,
    this.degraded = false,
  });

  const AdaptiveFeed.empty(this.persona)
      : items = const [],
        criticalCount = 0,
        degraded = false;

  final String persona;
  final List<AdaptivePriorityItem> items;
  final int criticalCount;

  /// True when a source was skipped for lack of permission — this feed is a
  /// subset of what a fully-permitted caller would see.
  final bool degraded;

  bool get isEmpty => items.isEmpty;
}

/// How a quick action resolves: `endpoint` = deterministic data (0 tokens);
/// `copilot` = governed t3 chat opened with a pre-filled prompt.
@immutable
class QuickActionResolver {
  const QuickActionResolver({required this.kind, required this.target, this.prompt});

  final String kind; // endpoint | copilot
  final String target;
  final String? prompt;

  bool get isCopilot => kind == 'copilot';
}

/// A predefined, RBAC-filtered persona action (doc 10 §7). `tier` t1 =
/// deterministic; t3 = generative (copilot).
@immutable
class AdaptiveQuickAction {
  const AdaptiveQuickAction({
    required this.id,
    required this.label,
    required this.tier,
    required this.resolver,
    this.requiresEntity,
  });

  final String id;
  final String label;
  final String tier; // t1 | t3
  final QuickActionResolver resolver;

  /// e.g. "student" when the action needs a selected entity first.
  final String? requiresEntity;

  bool get isDeterministic => tier == 't1';
}

/// One Universal Search hit — navigable, never an AI call (Search First).
@immutable
class SearchResultItem {
  const SearchResultItem({
    required this.category,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.deepLink,
  });

  final String category;
  final String id;
  final String title;

  /// Disambiguating identifiers (class-section · roll · adm# · id).
  final String subtitle;
  final String deepLink;
}

/// Search results grouped by category (decision 5).
@immutable
class SearchGroup {
  const SearchGroup({
    required this.category,
    required this.label,
    required this.results,
    required this.total,
  });

  final String category;
  final String label;
  final List<SearchResultItem> results;
  final int total;
}

@immutable
class UniversalSearchResult {
  const UniversalSearchResult({required this.query, required this.groups});

  const UniversalSearchResult.empty(this.query) : groups = const [];

  final String query;
  final List<SearchGroup> groups;

  bool get isEmpty => groups.isEmpty;
}
