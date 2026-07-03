import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_query.dart';
import '../../core/tenant/tenant_provider.dart';
import '../auth/auth_models.dart';
import '../auth/auth_provider.dart';
import '../phase5/phase5_providers.dart';
import 'attendance/parent_attendance_provider.dart';
import 'communication/parent_communication_inbox_provider.dart';
import 'dashboard/parent_dashboard_provider.dart';
import 'events/parent_events_provider.dart';
import 'exams/parent_exams_provider.dart';
import 'fees/fees_provider.dart';
import 'homework/parent_homework_provider.dart';
import 'leave/parent_leave_provider.dart';
import 'notices/parent_notices_provider.dart';
import 'profile/parent_profile_provider.dart';
import 'receipts/parent_receipts_provider.dart';
import 'timetable/parent_timetable_provider.dart';

/// Profile-module child id ⇆ canonical active child id.
///
/// The profile module historically keyed a child by an underscore variant
/// (`child_ravi`) while the auth/JWT `child_ids` value is the canonical id
/// (`child-ravi`). These maps ONLY bridge that presentation-layer key — they
/// are NOT an identity source. A student's identity is always the auth-backed
/// child id from `child_ids`; never a client-supplied / hardcoded SIS id.
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

/// Canonical active child for all parent modules (auth-backed).
final parentActiveChildProvider = Provider<LinkedChild?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.role != UserRole.parent) return null;
  return auth.selectedChild ??
      (auth.linkedChildren.isNotEmpty ? auth.linkedChildren.first : null);
});

/// Student ID for repository/API calls, derived from the active child.
///
/// This is the auth-backed child id present in the JWT `child_ids` claim — the
/// canonical student identity. It is NEVER a client-supplied or hardcoded SIS
/// id; the backend re-validates membership against `child_ids` and 403s an
/// unlinked child. Empty when no child is resolved (unauthenticated / no linked
/// children), so callers fall through rather than leaking a demo student.
final parentActiveStudentIdProvider = Provider<String>((ref) {
  final child = ref.watch(parentActiveChildProvider);
  return child?.id ?? '';
});

/// Tenant query scoped to the active child for ALL parent reads.
///
/// PAR-1: every parent read must carry `activeChildId` so the backend returns
/// *that* child's data instead of silently defaulting to `child_ids[0]`. The
/// child's id is the canonical linkage value present in the JWT `child_ids`
/// claim (see [linkedChildrenFromAuthUser]); the backend validates membership
/// and 403s an unlinked child.
final parentRepositoryQueryProvider = Provider<RepositoryQuery>((ref) {
  final query = ref.watch(repositoryQueryProvider);
  final child = ref.watch(parentActiveChildProvider);
  if (child == null || child.id.isEmpty) return query;
  return query.withAdditionalParams({'activeChildId': child.id});
});

/// Select child and propagate to auth session, refreshing EVERY per-child read.
///
/// PAR-2: on child-switch every module (fees/exams/receipts/attendance/homework/
/// timetable/notices/events/leave/profile/communication/dashboard/experience
/// hub) must drop the previous child's data. The scoped query providers already
/// recompute reactively, but we also sync the profile module's separate child id
/// and explicitly invalidate the full set so nothing can keep stale data.
Future<void> selectParentActiveChild(WidgetRef ref, LinkedChild child) async {
  await ref.read(authProvider.notifier).selectChild(child);

  // Keep the profile module's independent child id in lockstep with the switch.
  ref.read(parentProfileActiveChildProvider.notifier).state =
      kAuthChildToProfileId[child.id] ?? child.id.replaceAll('-', '_');

  ref.invalidate(parentActiveChildProvider);
  ref.invalidate(parentActiveStudentIdProvider);
  ref.invalidate(parentRepositoryQueryProvider);
  ref.invalidate(parentDashboardFutureProvider);
  ref.invalidate(parentExperienceHubProvider);
  ref.invalidate(parentProfileFutureProvider);
  ref.invalidate(parentAttendanceFutureProvider);
  ref.invalidate(parentHomeworkFutureProvider);
  ref.invalidate(parentExamsFutureProvider);
  ref.invalidate(parentTimetableFutureProvider);
  ref.invalidate(parentFeesFutureProvider);
  ref.invalidate(parentReceiptsFutureProvider);
  ref.invalidate(parentNoticesFutureProvider);
  ref.invalidate(parentEventsFutureProvider);
  ref.invalidate(parentLeaveHistoryFutureProvider);
  ref.invalidate(parentCommunicationInboxFutureProvider);
}
