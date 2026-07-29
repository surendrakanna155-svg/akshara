import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'manual_attendance_request_datasource.dart';
import 'manual_attendance_request_models.dart';

/// PRA-P0-15 — client seam for the audited manual-attendance fallback.
final manualAttendanceRequestDataSourceProvider =
    Provider<ManualAttendanceRequestDataSource>((ref) {
  return ManualAttendanceRequestRemoteDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
  );
});

/// The approver queue: pending manual requests for the active school. Refresh by
/// invalidating this provider after a decide.
final pendingManualAttendanceRequestsProvider =
    FutureProvider.autoDispose<List<ManualAttendanceRequest>>((ref) async {
  return ref.watch(manualAttendanceRequestDataSourceProvider).listPending();
});

/// Client-side gate for the approver queue nav entry.
///
/// Gated on the SAME slug the server enforces on the decide endpoint —
/// `approveStaffAttendance` — via the approve-class check, so this provider and
/// [ApprovePermissionGuard] on the route agree by construction.
///
/// This previously read `manageHr`, on a stale premise that the client
/// `Permission` enum did not carry the real slug. It does
/// ([Permission.approveStaffAttendance]), and the proxy was wrong in BOTH
/// directions: Principal and Vice-Principal — the approvers the attendance
/// design names — hold `approveStaffAttendance` but NOT `manageHr`, so they were
/// hidden from their own queue; while `hrManager` holds `manageHr` but not the
/// approve slug, so they saw a button the server would 403.
///
/// Overridable in tests.
final canApproveManualAttendanceProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasApprovePermission(Permission.approveStaffAttendance);
});
