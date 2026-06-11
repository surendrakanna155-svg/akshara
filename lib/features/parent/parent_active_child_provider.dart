import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_models.dart';
import '../auth/auth_provider.dart';
import '../phase5/phase5_providers.dart';
import 'dashboard/parent_dashboard_provider.dart';

/// Maps parent auth child IDs to student IDs used by Phase 5 / SIS APIs.
const Map<String, String> kParentChildToStudentId = {
  'child-ravi': 'student_1',
  'child-priya': 'student_2',
  'child_ravi': 'student_1',
  'child_ananya': 'student_2',
};

/// Profile mock IDs → auth session IDs.
const Map<String, String> kProfileChildToAuthId = {
  'child_ravi': 'child-ravi',
  'child_ananya': 'child-priya',
  'child-ravi': 'child-ravi',
  'child-priya': 'child-priya',
};

const Map<String, String> kAuthChildToProfileId = {
  'child-ravi': 'child_ravi',
  'child-priya': 'child_ananya',
};

String parentStudentIdForChild(String childId) =>
    kParentChildToStudentId[childId] ?? childId;

/// Canonical active child for all parent modules (auth-backed).
final parentActiveChildProvider = Provider<LinkedChild?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.role != UserRole.parent) return null;
  return auth.selectedChild ??
      (auth.linkedChildren.isNotEmpty ? auth.linkedChildren.first : null);
});

/// Student ID for repository/API calls derived from active child.
final parentActiveStudentIdProvider = Provider<String>((ref) {
  final child = ref.watch(parentActiveChildProvider);
  if (child == null) return 'student_1';
  return parentStudentIdForChild(child.id);
});

/// Select child and propagate to auth session (invalidates dependent providers).
Future<void> selectParentActiveChild(WidgetRef ref, LinkedChild child) async {
  await ref.read(authProvider.notifier).selectChild(child);
  ref.invalidate(parentActiveChildProvider);
  ref.invalidate(parentActiveStudentIdProvider);
  ref.invalidate(parentDashboardFutureProvider);
  ref.invalidate(parentExperienceHubProvider);
}
