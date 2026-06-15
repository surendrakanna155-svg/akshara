import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import 'parent_meeting_models.dart';

final parentMeetingsCanViewProvider = Provider<bool>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  return rbac.hasPermission(Permission.viewAcademicProgress);
});

final parentMeetingsCanManageProvider = Provider<bool>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  return rbac.hasPermission(Permission.manageAcademicProgress) ||
      rbac.hasPermission(Permission.manageAcademicTimetable);
});

final parentMeetingsFutureProvider = FutureProvider<List<ParentMeetingRecord>>((
  ref,
) async {
  return ref.read(parentMeetingsRepositoryProvider).listMeetings(
        query: ref.watch(repositoryQueryProvider),
      );
});

final selectedParentMeetingIdProvider = StateProvider<String?>((ref) => null);

final selectedParentMeetingProvider = Provider<ParentMeetingRecord?>((ref) {
  final selectedId = ref.watch(selectedParentMeetingIdProvider);
  if (selectedId == null) return null;
  final meetings = ref.watch(parentMeetingsFutureProvider).valueOrNull;
  if (meetings == null) return null;
  for (final meeting in meetings) {
    if (meeting.id == selectedId) return meeting;
  }
  return null;
});
