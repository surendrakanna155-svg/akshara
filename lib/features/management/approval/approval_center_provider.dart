import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/approvals/adapters/approval_adapter_registry.dart';
import '../../../core/approvals/adapters/inventory_po_approval_adapter.dart';
import '../../../core/approvals/approval_audit.dart';
import '../../../core/approvals/approval_category.dart';
import '../../../core/approvals/approval_models.dart';
import '../../../core/approvals/approval_request_type.dart';
import '../../../core/approvals/approval_permissions.dart';
import '../../../core/approvals/approval_requests.dart';
import '../../../core/approvals/approval_status.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/mock/mock_approval_demo_seed.dart';
import '../../../core/repositories/mock/mock_approval_repository.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../core/notifications/approval_notification_service.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/finance/fee_structures/finance_fee_structures_provider.dart';
import '../../../features/hr/hr_providers.dart';
import '../../../features/inventory/inventory_providers.dart';
import '../../../features/parent/attendance/parent_attendance_provider.dart';
import '../../../features/parent/exams/parent_exams_provider.dart';
import '../../../features/parent/leave/parent_leave_provider.dart';
import '../../../features/student/exams/student_exams_provider.dart';
import '../../../features/teacher/exams/teacher_exams_provider.dart';
import '../management_models.dart';

// ── Filter state ────────────────────────────────────────────────────────────

final approvalCenterStatusFilterProvider = StateProvider<int>((ref) => 0);

final approvalCenterCategoryFilterProvider =
    StateProvider<ApprovalCategory>((ref) => ApprovalCategory.all);

final approvalCenterSelectedIdProvider = StateProvider<String?>((ref) => null);

final approvalCenterLoadingProvider = StateProvider<bool>((ref) => false);
final approvalCenterErrorProvider = StateProvider<bool>((ref) => false);

// ── Data loading ────────────────────────────────────────────────────────────

final approvalCenterFutureProvider =
    FutureProvider<List<ApprovalRequest>>((ref) async {
  final query = ref.watch(repositoryQueryProvider);
  final service = ref.read(approvalCenterServiceProvider);
  final repo = ref.read(approvalRepositoryProvider);
  if (repo is MockApprovalRepository) {
    await seedMockApprovalDemoIfEmpty(repository: repo, query: query);
  }
  return service.listByFilter(
    query: query,
    filter: const ApprovalListFilter(),
  );
});

final approvalCenterListProvider = Provider<List<ApprovalRequest>>((ref) {
  return watchRepositoryFuture(
        ref,
        ref.watch(approvalCenterFutureProvider),
        manualLoading: ref.watch(approvalCenterLoadingProvider),
        manualError: ref.watch(approvalCenterErrorProvider),
        manualEmpty: false,
      ) ??
      const [];
});

final approvalCenterFilteredListProvider =
    Provider<List<ApprovalRequest>>((ref) {
  final items = ref.watch(approvalCenterListProvider);
  final statusIndex = ref.watch(approvalCenterStatusFilterProvider);
  final category = ref.watch(approvalCenterCategoryFilterProvider);

  return items.where((item) {
    final statusMatch = switch (statusIndex) {
      1 => item.status == ApprovalStatus.pending,
      2 => item.status == ApprovalStatus.approved,
      3 => item.status == ApprovalStatus.rejected,
      _ => true,
    };
    if (!statusMatch) return false;
    return category.matchesType(item.type);
  }).toList(growable: false);
});

final approvalCenterPendingCountProvider = Provider<int>((ref) {
  final items = ref.watch(approvalCenterListProvider);
  return items.where((a) => a.status == ApprovalStatus.pending).length;
});

/// Pending approvals older than 48 hours (M-D7 escalation insight).
final approvalCenterStalePendingCountProvider = Provider<int>((ref) {
  final items = ref.watch(approvalCenterListProvider);
  final now = DateTime.now().toUtc();
  return items.where((a) {
    if (a.status != ApprovalStatus.pending) return false;
    return now.difference(a.createdAt.toUtc()).inHours > 48;
  }).length;
});

final approvalCenterSelectedProvider = Provider<ApprovalRequest?>((ref) {
  final selectedId = ref.watch(approvalCenterSelectedIdProvider);
  if (selectedId == null) return null;
  final items = ref.watch(approvalCenterFilteredListProvider);
  for (final item in items) {
    if (item.id == selectedId) return item;
  }
  return null;
});

final approvalCenterAuditFutureProvider =
    FutureProvider.family<List<ApprovalAuditEntry>, String>(
  (ref, approvalId) async {
    final query = ref.watch(repositoryQueryProvider);
    return ref.read(approvalCenterServiceProvider).listAuditEntries(
          query: query,
          approvalRequestId: approvalId,
        );
  },
);

final approvalCenterKpisProvider = Provider<List<ManagementKpi>>((ref) {
  final items = ref.watch(approvalCenterListProvider);
  final now = DateTime.now().toUtc();
  final pending =
      items.where((a) => a.status == ApprovalStatus.pending).length;
  final approvedToday = items.where((a) {
    final decided = a.decidedAt;
    return a.status == ApprovalStatus.approved &&
        decided != null &&
        decided.year == now.year &&
        decided.month == now.month &&
        decided.day == now.day;
  }).length;
  final rejectedWeek = items.where((a) {
    final decided = a.decidedAt;
    return a.status == ApprovalStatus.rejected &&
        decided != null &&
        now.difference(decided).inDays <= 7;
  }).length;

  return [
    ManagementKpi(
      id: 'pending',
      value: '$pending',
      label: 'Pending',
      icon: Icons.pending_actions_outlined,
      accentName: 'warning',
    ),
    ManagementKpi(
      id: 'approved_today',
      value: '$approvedToday',
      label: 'Approved Today',
      icon: Icons.check_circle_outline,
      accentName: 'success',
    ),
    ManagementKpi(
      id: 'rejected',
      value: '$rejectedWeek',
      label: 'Rejected (week)',
      icon: Icons.cancel_outlined,
      accentName: 'error',
    ),
    ManagementKpi(
      id: 'total',
      value: '${items.length}',
      label: 'Total Requests',
      icon: Icons.inbox_outlined,
      accentName: 'neutral',
    ),
  ];
});

// ── Mutations ───────────────────────────────────────────────────────────────

void assertApprovalPermission(Ref ref, Permission permission) {
  final rbac = ref.read(rbacServiceProvider);
  final allowed = rbac.hasApprovePermission(permission) ||
      rbac.hasManagePermission(permission);
  if (!allowed) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to decide this approval.',
        code: 'RBAC_APPROVAL_DENIED',
      ),
    );
  }
}

(String actorId, String actorName) _approvalActor(Ref ref) {
  final auth = ref.read(authProvider);
  final claims = auth.claims;
  return (
    claims?.userId ?? 'principal_001',
    auth.displayName ?? claims?.erpRole.label ?? 'Principal',
  );
}

class ResolveApprovalRequestNotifier extends AsyncNotifier<ApprovalRequest?> {
  @override
  FutureOr<ApprovalRequest?> build() => null;

  Future<ApprovalRequest?> approve({
    required ApprovalRequest request,
    String? comment,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertApprovalPermission(
        ref,
        approvalPermissionForType(request.type),
      );
      final (actorId, actorName) = _approvalActor(ref);
      if (request.type == ApprovalRequestType.inventoryPo) {
        InventoryPoApprovalAdapter.assertApproverNotCreator(
          request: request,
          actorId: actorId,
        );
      }
      final result = await ref.read(approvalCenterServiceProvider).approveRequest(
            query: ref.read(repositoryQueryProvider),
            request: ApproveApprovalRequest(
              approvalId: request.id,
              actorId: actorId,
              actorName: actorName,
              comment: comment,
            ),
          );
      final query = ref.read(repositoryQueryProvider);
      ApprovalAdapterRegistry.dispatchApproved(query: query, request: result);
      _invalidateAfterApprovalSideEffects(ref, result.type);
      _recordApprovalNotification(ref, result, approved: true, comment: comment);
      ref.invalidate(approvalCenterFutureProvider);
      ref.invalidate(approvalCenterAuditFutureProvider(request.id));
      return result;
    });
    return state.valueOrNull;
  }

  Future<ApprovalRequest?> reject({
    required ApprovalRequest request,
    required String comment,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertApprovalPermission(
        ref,
        approvalPermissionForType(request.type),
      );
      final (actorId, actorName) = _approvalActor(ref);
      final result = await ref.read(approvalCenterServiceProvider).rejectRequest(
            query: ref.read(repositoryQueryProvider),
            request: RejectApprovalRequest(
              approvalId: request.id,
              actorId: actorId,
              actorName: actorName,
              comment: comment.trim(),
            ),
          );
      final query = ref.read(repositoryQueryProvider);
      ApprovalAdapterRegistry.dispatchRejected(
        query: query,
        request: result,
        comment: comment.trim(),
      );
      _recordApprovalNotification(
        ref,
        result,
        approved: false,
        comment: comment.trim(),
      );
      ref.invalidate(approvalCenterFutureProvider);
      ref.invalidate(approvalCenterAuditFutureProvider(request.id));
      return result;
    });
    return state.valueOrNull;
  }
}

final resolveApprovalRequestProvider =
    AsyncNotifierProvider<ResolveApprovalRequestNotifier, ApprovalRequest?>(
  ResolveApprovalRequestNotifier.new,
);

void _invalidateAfterApprovalSideEffects(Ref ref, ApprovalRequestType type) {
  switch (type) {
    case ApprovalRequestType.examResults:
      ref.invalidate(studentExamsFutureProvider);
      ref.invalidate(parentExamsFutureProvider);
      ref.invalidate(teacherExamMarksFutureProvider);
      ref.invalidate(teacherUpcomingExamsFutureProvider);
    case ApprovalRequestType.studentLeave:
      ref.invalidate(parentLeaveHistoryFutureProvider);
    case ApprovalRequestType.staffLeave:
      ref.invalidate(hrLeaveFutureProvider);
    case ApprovalRequestType.attendanceCorrection:
      ref.invalidate(parentAttendanceFutureProvider);
    case ApprovalRequestType.feeStructure:
    case ApprovalRequestType.feeConcession:
    case ApprovalRequestType.refund:
      ref.invalidate(financeFeeStructuresFutureProvider);
    case ApprovalRequestType.inventoryPo:
      ref.invalidate(inventoryProcurementFutureProvider);
    default:
      break;
  }
}

void _recordApprovalNotification(
  Ref ref,
  ApprovalRequest request, {
  required bool approved,
  String? comment,
}) {
  if (!ref.read(approvalNotificationsEnabledProvider)) return;
  ref.read(approvalNotificationServiceProvider).recordDecision(
        request: request,
        approved: approved,
        comment: comment,
      );
}
