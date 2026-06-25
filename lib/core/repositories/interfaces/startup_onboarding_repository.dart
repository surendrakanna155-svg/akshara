import 'package:flutter/foundation.dart';

import '../../../features/onboarding/ai_school_builder_models.dart';
import '../../../features/onboarding/unified_onboarding_models.dart';
import '../repository_query.dart';

/// Result of a go-live attempt — includes validation errors when blocked.
@immutable
class StartupOnboardingGoLiveResult {
  const StartupOnboardingGoLiveResult({
    required this.state,
    required this.validationErrors,
  });

  final UnifiedOnboardingState state;
  final List<String> validationErrors;

  bool get succeeded => validationErrors.isEmpty && state.isLive;
}

/// Result of an AI pre-fill: the proposal applied onto the wizard state, plus
/// metadata about where the proposal came from. Non-destructive — the caller
/// reviews/refines before saving and going live.
@immutable
class StartupOnboardingPrefillResult {
  const StartupOnboardingPrefillResult({
    required this.state,
    required this.meta,
  });

  final UnifiedOnboardingState state;
  final SchoolBlueprintResult meta;
}

abstract class StartupOnboardingRepository {
  Future<UnifiedOnboardingState> load({required RepositoryQuery query});

  Future<UnifiedOnboardingState> save({
    required RepositoryQuery query,
    required UnifiedOnboardingState state,
  });

  Future<StartupOnboardingGoLiveResult> goLive({required RepositoryQuery query});

  /// AI School Builder (Phase 1): propose a complete school structure/config
  /// from a short brief, applied onto [current] for review.
  Future<StartupOnboardingPrefillResult> aiPrefill({
    required RepositoryQuery query,
    required SchoolBrief brief,
    required UnifiedOnboardingState current,
  });
}
