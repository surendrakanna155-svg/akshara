import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
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
      return _runMutation(
        ref,
        auditAction: 'submitLeaveRequest',
        entityId: 'leave',
        entityIdForAudit: (leave) => leave.id,
        invalidateLeaveHistory: true,
        action: () => ref.read(parentRepositoryProvider).submitLeaveRequest(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
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
