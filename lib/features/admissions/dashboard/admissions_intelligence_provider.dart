import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../admissions_models.dart';

/// B4 — AI Admissions Assistant next-best-actions for the dashboard card.
final admissionsIntelligenceFutureProvider =
    FutureProvider<AdmissionsIntelligenceData>((ref) async {
  return ref.read(admissionsRepositoryProvider).getIntelligence(
        query: ref.watch(repositoryQueryProvider),
      );
});

/// Soft accessor — null while loading or on error, so the card degrades
/// gracefully without ever blocking the dashboard.
final admissionsIntelligenceProvider =
    Provider<AdmissionsIntelligenceData?>((ref) {
  return ref.watch(admissionsIntelligenceFutureProvider).whenOrNull(
        data: (data) => data,
      );
});
