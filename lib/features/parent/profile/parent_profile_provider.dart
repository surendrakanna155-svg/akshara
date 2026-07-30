import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'profile_models.dart';

final parentProfileLoadingProvider = StateProvider<bool>((ref) => false);
final parentProfileErrorProvider = StateProvider<bool>((ref) => false);
final parentProfileEmptyProvider = StateProvider<bool>((ref) => false);

/// Active child id for profile API (mock profile child ids).
final parentProfileActiveChildProvider = StateProvider<String>(
  (ref) => 'child_ravi',
);

final parentProfileFutureProvider = FutureProvider<ParentProfileData>((ref) async {
  return ref.read(parentRepositoryProvider).getProfile(
        query: ref.watch(repositoryQueryProvider),
        activeChildId: ref.watch(parentProfileActiveChildProvider),
      );
});

final parentProfileProvider = Provider<ParentProfileData>((ref) {
  final data = watchRepositoryFuture(
    ref,
    ref.watch(parentProfileFutureProvider),
    manualLoading: ref.watch(parentProfileLoadingProvider),
    manualError: ref.watch(parentProfileErrorProvider),
    manualEmpty: ref.watch(parentProfileEmptyProvider),
  );
  // Honest-async contract (same class as CERT-001/CERT-002): the fallback used
  // to be a complete fabricated family — "Suresh Kumar", a phone number, an
  // email, a school and a child "Ravi Kumar, 8-A". A parent whose profile call
  // failed was shown someone else's identity as their own.
  return data ??
      ref.watch(parentProfileFutureProvider).value ??
      const ParentProfileData(
        parentName: '',
        phoneLabel: '',
        email: '',
        schoolName: '',
        unreadNotifications: 0,
        children: [],
      );
});
