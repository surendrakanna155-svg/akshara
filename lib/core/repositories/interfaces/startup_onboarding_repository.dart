import 'package:flutter/foundation.dart';

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

abstract class StartupOnboardingRepository {
  Future<UnifiedOnboardingState> load({required RepositoryQuery query});

  Future<UnifiedOnboardingState> save({
    required RepositoryQuery query,
    required UnifiedOnboardingState state,
  });

  Future<StartupOnboardingGoLiveResult> goLive({required RepositoryQuery query});
}
