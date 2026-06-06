import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_models.dart';

/// Reserved for API loading state.
final parentProfileLoadingProvider = StateProvider<bool>((ref) => false);

/// Reserved for API error state.
final parentProfileErrorProvider = StateProvider<bool>((ref) => false);

/// Active child id for profile child switcher preview.
final parentProfileActiveChildProvider = StateProvider<String>(
  (ref) => 'child_ravi',
);

/// Mock parent profile payload.
final parentProfileProvider = Provider<ParentProfileData>((ref) {
  final activeChildId = ref.watch(parentProfileActiveChildProvider);

  return ParentProfileData(
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
        isActive: activeChildId == 'child_ravi',
      ),
      ParentChildProfile(
        id: 'child_ananya',
        name: 'Ananya Kumar',
        classLabel: '5-B',
        isActive: activeChildId == 'child_ananya',
      ),
    ],
  );
});
