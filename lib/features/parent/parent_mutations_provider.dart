import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/approvals/adapters/attendance_correction_approval_adapter.dart';
import '../../core/approvals/adapters/student_leave_approval_adapter.dart';
import '../../core/attendance/attendance_correction_models.dart';
import '../../core/config/leave_approval_config.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';
import 'fees/fees_provider.dart';
import 'leave/leave_models.dart';
import 'leave/parent_leave_provider.dart';
import 'parent_audit.dart';
import 'parent_requests.dart';
import 'payment/payment_models.dart';
import 'payment/parent_payment_provider.dart';

void _invalidateParentReads(
  Ref ref, {
  bool leaveHistory = false,
  bool fees = false,
  bool paymentSummary = false,
}) {
  if (leaveHistory) ref.invalidate(parentLeaveHistoryFutureProvider);
  if (fees) ref.invalidate(parentFeesFutureProvider);
  if (paymentSummary) {
    final installmentId = ref.read(parentPaymentInstallmentIdProvider);
    ref.invalidate(parentPaymentSummaryFutureProvider(installmentId));
  }
}

Future<T?> _runMutation<T>(
  Ref ref, {
  required Future<T> Function() action,
  required String auditAction,
  required String entityId,
  String Function(T result)? entityIdForAudit,
  Map<String, String> metadata = const {},
  bool invalidateLeaveHistory = false,
  bool invalidateFees = false,
  bool invalidatePaymentSummary = false,
}) async {
  try {
    final result = await action();
    await recordParentAudit(
      ref,
      action: auditAction,
      entityId: entityIdForAudit?.call(result) ?? entityId,
      metadata: metadata,
    );
    _invalidateParentReads(
      ref,
      leaveHistory: invalidateLeaveHistory,
      fees: invalidateFees,
      paymentSummary: invalidatePaymentSummary,
    );
    return result;
  } catch (error) {
    final failure = apiFailureMapper.fromException(error);
    throw ApiFailureException(failure);
  }
}

class SubmitParentLeaveNotifier extends AsyncNotifier<LeaveRequest?> {
  @override
  FutureOr<LeaveRequest?> build() => null;

  Future<LeaveRequest?> execute(ParentLeaveSubmitRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final rbac = ref.read(rbacServiceProvider);
      if (!rbac.hasPermission(Permission.submitStudentLeave)) {
        throw ApiFailureException(
          ApiFailure(
            type: ApiFailureType.forbidden,
            message: 'You do not have permission to submit student leave.',
            code: 'RBAC_SUBMITSTUDENTLEAVE',
          ),
        );
      }

      final leave = await _runMutation(
        ref,
        auditAction: 'submitLeaveRequest',
        entityId: 'leave',
        entityIdForAudit: (item) => item.id,
        invalidateLeaveHistory: true,
        action: () => ref.read(parentRepositoryProvider).submitLeaveRequest(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );

      if (leave != null && ref.read(leaveApprovalRequiredProvider)) {
        final auth = ref.read(authProvider);
        final claims = auth.claims;
        final adapter = StudentLeaveApprovalAdapter();
        await adapter.submitForApproval(
          service: ref.read(approvalCenterServiceProvider),
          query: ref.read(repositoryQueryProvider),
          leaveId: leave.id,
          requesterId: claims?.userId ?? 'parent_demo',
          requesterName: auth.displayName ?? 'Parent',
          title: '${leave.childName} — ${leave.type.label}',
          summary:
              '${leave.fromDateLabel} to ${leave.toDateLabel} · ${leave.childClass}',
          payload: {
            'childId': request.childId,
            'childName': leave.childName,
            'classLabel': leave.childClass,
            'fromDate': leave.fromDateLabel,
            'toDate': leave.toDateLabel,
            'leaveType': leave.type.label,
            'reason': leave.reason,
            'hasAttachment': leave.hasAttachment,
          },
        );
      }

      return leave;
    });
    return state.valueOrNull;
  }
}

final submitParentLeaveProvider =
    AsyncNotifierProvider<SubmitParentLeaveNotifier, LeaveRequest?>(
  SubmitParentLeaveNotifier.new,
);

class InitiateParentPaymentNotifier extends AsyncNotifier<PaymentInitiationResult?> {
  @override
  FutureOr<PaymentInitiationResult?> build() => null;

  Future<PaymentInitiationResult?> execute(
    ParentPaymentInitiateRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        auditAction: 'initiatePayment',
        entityId: request.installmentId,
        entityIdForAudit: (result) => result.paymentIntentId,
        metadata: {'installmentId': request.installmentId},
        action: () => ref.read(parentRepositoryProvider).initiatePayment(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final initiateParentPaymentProvider =
    AsyncNotifierProvider<InitiateParentPaymentNotifier, PaymentInitiationResult?>(
  InitiateParentPaymentNotifier.new,
);

class ConfirmParentPaymentNotifier extends AsyncNotifier<PaymentConfirmationResult?> {
  @override
  FutureOr<PaymentConfirmationResult?> build() => null;

  Future<PaymentConfirmationResult?> execute(
    ParentPaymentConfirmRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        auditAction: 'confirmPayment',
        entityId: request.paymentIntentId,
        entityIdForAudit: (result) => result.receiptId,
        invalidateFees: true,
        invalidatePaymentSummary: true,
        action: () => ref.read(parentRepositoryProvider).confirmPayment(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final confirmParentPaymentProvider =
    AsyncNotifierProvider<ConfirmParentPaymentNotifier, PaymentConfirmationResult?>(
  ConfirmParentPaymentNotifier.new,
);

class SubmitParentAttendanceCorrectionNotifier
    extends AsyncNotifier<ParentAttendanceCorrectionResult?> {
  @override
  FutureOr<ParentAttendanceCorrectionResult?> build() => null;

  Future<ParentAttendanceCorrectionResult?> execute(
    ParentAttendanceCorrectionRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final rbac = ref.read(rbacServiceProvider);
      if (!rbac.hasPermission(Permission.submitAttendanceCorrection)) {
        throw ApiFailureException(
          ApiFailure(
            type: ApiFailureType.forbidden,
            message:
                'You do not have permission to submit attendance corrections.',
            code: 'RBAC_SUBMITATTENDANCECORRECTION',
          ),
        );
      }

      final auth = ref.read(authProvider);
      final requesterId = auth.claims?.userId ?? 'parent_demo';
      final requesterName = auth.displayName ?? 'Parent';

      final parts = request.classLabel.split('-');
      final classLabel = parts.isNotEmpty ? parts.first.trim() : request.classLabel;
      final section = parts.length > 1 ? parts.last.trim() : 'A';

      final correction = await ref
          .read(attendanceCorrectionRepositoryProvider)
          .createCorrection(
            query: ref.read(repositoryQueryProvider),
            request: CreateAttendanceCorrectionRequest(
              sisStudentId: request.sisStudentId,
              studentName: request.childName,
              classLabel: classLabel,
              section: section,
              dateLabel: request.dateLabel,
              fromMark: request.fromMark,
              toMark: request.toMark,
              reason: request.reason,
              requesterId: requesterId,
              requesterName: requesterName,
              requesterRole: 'parent',
            ),
          );

      final adapter = AttendanceCorrectionApprovalAdapter();
      final approval = await adapter.submitForApproval(
        service: ref.read(approvalCenterServiceProvider),
        query: ref.read(repositoryQueryProvider),
        entityId: correction.id,
        requesterId: requesterId,
        requesterName: requesterName,
        title: 'Attendance correction — ${request.childName}',
        summary:
            '${request.dateLabel} · ${request.fromMark} → ${request.toMark}',
        payload: {
          'classLabel': classLabel,
          'section': section,
          'date': request.dateLabel,
          'fromMark': request.fromMark,
          'toMark': request.toMark,
          'studentsAffected': 1,
          'presentDelta': request.toMark == 'Present' ? 1 : 0,
          'requesterRole': 'parent',
          'studentName': request.childName,
          'reason': request.reason,
        },
      );

      await recordParentAudit(
        ref,
        action: 'submitAttendanceCorrection',
        entityId: correction.id,
        metadata: {'approvalId': approval.id},
      );

      return ParentAttendanceCorrectionResult(
        correctionId: correction.id,
        approvalId: approval.id,
      );
    });
    return state.valueOrNull;
  }
}

final submitParentAttendanceCorrectionProvider = AsyncNotifierProvider<
    SubmitParentAttendanceCorrectionNotifier, ParentAttendanceCorrectionResult?>(
  SubmitParentAttendanceCorrectionNotifier.new,
);
