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
/// The server enforces the exact `approveStaffAttendance` slug on the decide
/// endpoint (the authoritative gate). The client `Permission` enum does not yet
/// carry that slug, so the nav entry is gated on the closest representable
/// supervisory permission — `manageHr` (held by school-admin / management /
/// super-admin). Overridable in tests.
final canApproveManualAttendanceProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.manageHr);
});
