import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/tenant_provider.dart';
import '../../core/repositories/repository_providers.dart';
import 'onboarding_models.dart';

final onboardingDashboardProvider = FutureProvider<OnboardingDashboardData>((ref) async {
  return ref.read(onboardingRepositoryProvider).getDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final onboardingInvitesProvider = FutureProvider<List<OnboardingInvite>>((ref) async {
  return ref.read(onboardingRepositoryProvider).listInvites(
        query: ref.watch(repositoryQueryProvider),
      );
});
