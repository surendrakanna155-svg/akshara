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
import '../../../core/repositories/repository_config.dart';
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
import '../../../features/phase5/phase5_providers.dart';
import '../../../features/parent/leave/parent_leave_provider.dart';
import '../../../features/student_app/exams/student_exams_provider.dart';
import '../../../features/teacher/exams/teacher_exams_provider.dart';
import '../management_models.dart';

// ── Filter state ────────────────────────────────────────────────────────────

final approvalCenterStatusFilterProvider = StateProvider<int>((ref) => 0);

final approvalCenterCategoryFilterProvider =
    StateProvider<ApprovalCategory>((ref) => ApprovalCategory.all);

final approvalCenterSelectedIdProvider = StateProvider<String?>((ref) => null);

/// PRI-1 — multi-select set of approval ids picked for a batch decision.
/// Replaces single-select for batch actions; the single-select detail provider
/// stays for the review panel.
final approvalCenterSelectionProvider =
    StateProvider<Set<String>>((ref) => <String>{});

/// PRI-5 — when true, the queue is filtered to stale (>48h) pending approvals.
final approvalCenterStaleFilterProvider = StateProvider<bool>((ref) => false);

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

/// M-D7 — a pending approval is "stale" when it has waited more than 48h.
bool approvalIsStale(ApprovalRequest request, {DateTime? now}) {
  if (request.status != ApprovalStatus.pending) return false;
  final reference = (now ?? DateTime.now()).toUtc();
  return reference.difference(request.createdAt.toUtc()).inHours > 48;
}

final approvalCenterFilteredListProvider =
    Provider<List<ApprovalRequest>>((ref) {
  final items = ref.watch(approvalCenterListProvider);
  final statusIndex = ref.watch(approvalCenterStatusFilterProvider);
  final category = ref.watch(approvalCenterCategoryFilterProvider);
  final staleOnly = ref.watch(approvalCenterStaleFilterProvider);
  final now = DateTime.now().toUtc();

  return items.where((item) {
    final statusMatch = switch (statusIndex) {
      1 => item.status == ApprovalStatus.pending,
      2 => item.status == ApprovalStatus.approved,
      3 => item.status == ApprovalStatus.rejected,
      _ => true,
    };
    if (!statusMatch) return false;
    if (staleOnly && !approvalIsStale(item, now: now)) return false;
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
  return items.where((a) => approvalIsStale(a, now: now)).length;
});

/// PRI-4 — a single line item in the weekly principal digest.
@immutable
class PrincipalDigestItem {
  const PrincipalDigestItem({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;

  /// 'warning' | 'error' | 'success' | 'neutral' — mapped to a KpiAccent by the
  /// card, so the model stays widget-agnostic.
  final String tone;
}

/// PRI-4 — the in-app weekly principal digest: top priorities / risks / pending
/// composed from the already-loaded approval queue + operations-hub aggregates.
/// No cron — a pure read (XCT-2 owns the scheduled send).
@immutable
class PrincipalDigest {
  const PrincipalDigest({required this.items});

  final List<PrincipalDigestItem> items;

  bool get isEmpty => items.isEmpty;
}

final principalDigestProvider = Provider<PrincipalDigest>((ref) {
  final items = <PrincipalDigestItem>[];

  final pending = ref.watch(approvalCenterPendingCountProvider);
  final stale = ref.watch(approvalCenterStalePendingCountProvider);
  items.add(PrincipalDigestItem(
    label: 'Approvals pending',
    value: '$pending',
    tone: pending > 0 ? 'warning' : 'success',
  ));
  if (stale > 0) {
    items.add(PrincipalDigestItem(
      label: 'Waiting > 48h',
      value: '$stale',
      tone: 'error',
    ));
  }

  // Operations-hub aggregates (school health + risks + pending actions). Only
  // fold them in once the snapshot has loaded — a read card must never block.
  final hub = ref.watch(operationsHubProvider);
  hub.whenData((snapshot) {
    items.add(PrincipalDigestItem(
      label: 'School health',
      value: '${snapshot.schoolHealth}/100',
      tone: snapshot.schoolHealth >= 75
          ? 'success'
          : snapshot.schoolHealth >= 50
              ? 'warning'
              : 'error',
    ));
    if (snapshot.criticalAlerts.isNotEmpty) {
      items.add(PrincipalDigestItem(
        label: 'Critical alerts',
        value: '${snapshot.criticalAlerts.length}',
        tone: 'error',
      ));
    }
    if (snapshot.pendingActions.isNotEmpty) {
      items.add(PrincipalDigestItem(
        label: 'Pending actions',
        value: '${snapshot.pendingActions.length}',
        tone: 'warning',
      ));
    }
    final risks = snapshot.widgets.studentRiskAlerts +
        snapshot.widgets.employeeRiskAlerts;
    if (risks > 0) {
      items.add(PrincipalDigestItem(
        label: 'Student / staff risks',
        value: '$risks',
        tone: 'warning',
      ));
    }
  });

  return PrincipalDigest(items: items);
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

bool _skipApprovalDomainEffects(Ref ref) =>
    isModuleApiEnabled(ref, approvalApiEnabledProvider);

(String actorId, String actorName) _approvalActor(Ref ref) {
  final auth = ref.read(authProvider);
  final claims = auth.claims;
  final actorId = claims?.userId;
  // PRN-3: fail closed — never attribute an approval to a synthetic principal.
  if (actorId == null || actorId.isEmpty) {
    throw StateError('Approval requires an authenticated approver.');
  }
  return (
    actorId,
    auth.displayName ?? claims?.erpRole.label ?? 'Approver',
  );
}

class ResolveApprovalRequestNotifier extends AsyncNotifier<ApprovalRequest?> {
  @override
  FutureOr<ApprovalRequest?> build() => null;

  Future<ApprovalRequest?> approve({
    required ApprovalRequest request,
    String? comment,
  }) async {
    if (state.isLoading) return state.valueOrNull;
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
      ApprovalAdapterRegistry.dispatchApproved(
        query: query,
        request: result,
        skipDomainEffects: _skipApprovalDomainEffects(ref),
      );
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
    if (state.isLoading) return state.valueOrNull;
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
        skipDomainEffects: _skipApprovalDomainEffects(ref),
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

/// PRI-1 — batch approve/reject over the multi-selected approval ids. The route
/// is reachable to any management viewer, but per-item authority still governs
/// each id: a type the user cannot approve is reported as skipped('forbidden'),
/// never a blanket denial — so the batch and single paths cannot diverge.
class BatchDecideApprovalsNotifier extends AsyncNotifier<BatchDecisionResult?> {
  @override
  FutureOr<BatchDecisionResult?> build() => null;

  Future<BatchDecisionResult?> decide({
    required List<ApprovalRequest> requests,
    required ApprovalBatchDecision decision,
    String? comment,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    // Reject requires a non-empty comment — mirror the single-reject 422 up
    // front so we never round-trip a shape-invalid request.
    if (decision == ApprovalBatchDecision.reject &&
        (comment == null || comment.trim().isEmpty)) {
      throw ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.unknown,
          message: 'A rejection comment is required.',
          code: 'APPROVAL_REJECT_COMMENT_REQUIRED',
        ),
      );
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Reachability gate (same slug the server uses to reach the route).
      final rbac = ref.read(rbacServiceProvider);
      if (!rbac.hasPermission(Permission.viewManagement)) {
        throw ApiFailureException(
          const ApiFailure(
            type: ApiFailureType.forbidden,
            message: 'You do not have permission to decide approvals.',
            code: 'RBAC_APPROVAL_DENIED',
          ),
        );
      }

      // Per-item authority: only ids the user may actually decide are sent; the
      // rest surface as forbidden skips (matches the server's per-type gate).
      final authorized = <String>[];
      final forbidden = <ApprovalBatchSkippedItem>[];
      for (final request in requests) {
        final permission = approvalPermissionForType(request.type);
        final allowed = rbac.hasApprovePermission(permission) ||
            rbac.hasManagePermission(permission);
        if (allowed) {
          authorized.add(request.id);
        } else {
          forbidden.add(
            ApprovalBatchSkippedItem(
              id: request.id,
              reason: 'forbidden: ${permission.name}',
            ),
          );
        }
      }

      final (actorId, actorName) = _approvalActor(ref);
      BatchDecisionResult result = const BatchDecisionResult();
      if (authorized.isNotEmpty) {
        result = await ref.read(approvalCenterServiceProvider).batchDecide(
              query: ref.read(repositoryQueryProvider),
              request: BatchDecideApprovalsRequest(
                ids: authorized,
                decision: decision,
                actorId: actorId,
                actorName: actorName,
                comment: comment?.trim(),
              ),
            );
      }

      // Fold client-side forbidden skips into the server result.
      final merged = BatchDecisionResult(
        decided: result.decided,
        skipped: [...result.skipped, ...forbidden],
      );

      _invalidateAfterBatchDecision(ref, requests, merged);
      return merged;
    });
    if (state.hasError) throw state.error!;
    return state.valueOrNull;
  }
}

final batchDecideApprovalsProvider =
    AsyncNotifierProvider<BatchDecideApprovalsNotifier, BatchDecisionResult?>(
  BatchDecideApprovalsNotifier.new,
);

/// Refresh the approval list, per-item audit trails, and any domain effects for
/// the decided types after a batch decision.
void _invalidateAfterBatchDecision(
  Ref ref,
  List<ApprovalRequest> requests,
  BatchDecisionResult result,
) {
  final decidedIds = {for (final d in result.decided) d.id};
  final decidedTypes = <ApprovalRequestType>{};
  for (final request in requests) {
    if (decidedIds.contains(request.id)) {
      decidedTypes.add(request.type);
      ref.invalidate(approvalCenterAuditFutureProvider(request.id));
    }
  }
  for (final type in decidedTypes) {
    _invalidateAfterApprovalSideEffects(ref, type);
  }
  ref.invalidate(approvalCenterFutureProvider);
}

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
