import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'profile_models.dart';

final parentProfileLoadingProvider = StateProvider<bool>((ref) => false);
final parentProfileErrorProvider = StateProvider<bool>((ref) => false);
final parentProfileEmptyProvider = StateProvider<bool>((ref) => false);

/// Active child id for profile child switcher preview.
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
  return data ??
      ref.watch(parentProfileFutureProvider).value ??
      const ParentProfileData(
        parentName: 'Suresh Kumar',
        phoneLabel: '+91 98765 43210',
        email: 'suresh.kumar@email.com',
        schoolName: 'Akshara Public School',
        unreadNotifications: 2,
        children: [
          ParentChildProfile(
            id: 'child_ravi',
            name: 'Ravi Kumar',
            classLabel: '8-A',
            isActive: true,
          ),
        ],
      );
});
