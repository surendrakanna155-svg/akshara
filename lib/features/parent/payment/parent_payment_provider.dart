import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../shared/async/erp_async_state.dart';
import '../parent_mutations_provider.dart';
import '../parent_requests.dart';
import 'payment_models.dart';

/// Selected installment id (from route query).
///
/// JOURNEY-007: this starts EMPTY. It used to default to the demo fixture id
/// `'term_2'`, which is what made a fabricated ₹4,200 summary resolvable — and
/// payable — on a screen opened with no installment at all.
final parentPaymentInstallmentIdProvider = StateProvider<String>(
  (ref) => '',
);

/// Selected payment method in PA-10.
final parentPaymentMethodProvider = StateProvider<PaymentMethod>(
  (ref) => PaymentMethod.upi,
);

/// Current payment flow phase.
final parentPaymentPhaseProvider = StateProvider<PaymentFlowPhase>(
  (ref) => PaymentFlowPhase.summary,
);

/// Test hook to force a failed mock payment.
final parentPaymentSimulateFailureProvider = StateProvider<bool>(
  (ref) => false,
);

final parentPaymentLoadingProvider = StateProvider<bool>((ref) => false);
final parentPaymentErrorProvider = StateProvider<bool>((ref) => false);
final parentPaymentEmptyProvider = StateProvider<bool>((ref) => false);

/// Last successful payment result.
final parentPaymentSuccessResultProvider = StateProvider<PaymentSuccessResult?>(
  (ref) => null,
);

final parentPaymentSummaryFutureProvider = FutureProvider.family<PaymentSummary, String>((ref, installmentId) async {
  if (installmentId.trim().isEmpty) {
    // Nothing selected — do NOT ask the server for a summary and do NOT invent
    // one. The screen renders an honest "no payable installment" state.
    throw const NoPayableInstallmentSelected();
  }
  return ref.read(parentRepositoryProvider).getPaymentSummary(
        query: ref.watch(repositoryQueryProvider),
        installmentId: installmentId,
      );
});

/// Raised when the pay screen is opened without a real, server-issued
/// installment id. It is an honest empty state, not an error.
class NoPayableInstallmentSelected implements Exception {
  const NoPayableInstallmentSelected();
  @override
  String toString() => 'No payable installment selected';
}

/// JOURNEY-007 — honest-async contract for the pay screen.
///
/// There is no fallback summary. If the server did not issue one, [data] is
/// null, the summary view never renders and — see [submitParentPayment] — no
/// amount can reach `POST /parent/payments/initiate`.
final parentPaymentViewStateProvider = Provider<ErpViewState<PaymentSummary>>((
  ref,
) {
  final installmentId = ref.watch(parentPaymentInstallmentIdProvider);
  if (installmentId.trim().isEmpty && !ref.watch(parentPaymentErrorProvider)) {
    return const ErpViewState<PaymentSummary>(isEmpty: true);
  }
  return resolveErpAsync<PaymentSummary>(
    ref.watch(parentPaymentSummaryFutureProvider(installmentId)),
    forceLoading: ref.watch(parentPaymentLoadingProvider),
    forceError: ref.watch(parentPaymentErrorProvider),
    forceEmpty: ref.watch(parentPaymentEmptyProvider),
    errorMessage: 'Unable to load payment details.',
  );
});

/// Payment summary for the selected installment, or **null** when the server
/// has not issued one. Never a fabricated ₹4,200 for a fabricated child.
final parentPaymentSummaryProvider = Provider<PaymentSummary?>((ref) {
  return ref.watch(parentPaymentViewStateProvider).data;
});

/// Initiates a fee payment and — ONLY when handed VERIFIED gateway proof —
/// confirms it via the repository mutation providers.
///
/// PRA-P0-02 (client half): this is the fail-closed replacement for the former
/// `submitMockPayment`, which fabricated a transaction ref
/// (`txn_<millis>`) and reported [PaymentFlowPhase.success] with a receipt for
/// money that no real gateway ever took (the backend defaults to stub mode, so
/// the fake confirm always "succeeded"). We now REFUSE to claim success unless
/// [gatewayPayment] carries a verified gateway payment id + signature.
///
/// No payment-gateway SDK is wired yet — integrating one is an explicit OWNER
/// decision and is OUT OF SCOPE here — so [gatewayPayment] is always null at the
/// call site today. In that case the flow stops at
/// [PaymentFlowPhase.pendingGatewayVerification] after creating the intent, and
/// no receipt/success is ever shown. When an SDK is later added, its verified
/// callback flows through unchanged to the backend's already-built verification
/// path.
Future<void> submitParentPayment(
  WidgetRef ref, {
  VerifiedGatewayPayment? gatewayPayment,
}) async {
  ref.read(parentPaymentPhaseProvider.notifier).state =
      PaymentFlowPhase.processing;

  if (ref.read(parentPaymentSimulateFailureProvider)) {
    ref.read(parentPaymentPhaseProvider.notifier).state =
        PaymentFlowPhase.failure;
    return;
  }

  try {
    // ── JOURNEY-007 (P0) — MONEY GUARD ──────────────────────────────────────
    // Only a SERVER-ISSUED summary may be paid. Without one there is no amount
    // and no installment, so the initiate call is not made at all. This is the
    // last line of defence: even if a future screen re-enables the pay button
    // without a summary, no fabricated amount can reach the endpoint.
    final summary = ref.read(parentPaymentSummaryProvider);
    if (summary == null ||
        summary.installmentId.trim().isEmpty ||
        summary.totalAmount <= 0) {
      ref.read(parentPaymentPhaseProvider.notifier).state =
          PaymentFlowPhase.failure;
      return;
    }
    final method = ref.read(parentPaymentMethodProvider);

    final initiation = await ref
        .read(initiateParentPaymentProvider.notifier)
        .execute(
          ParentPaymentInitiateRequest(
            installmentId: summary.installmentId,
            paymentMethod: method,
            amount: summary.totalAmount,
          ),
        );

    if (initiation == null) {
      ref.read(parentPaymentPhaseProvider.notifier).state =
          PaymentFlowPhase.failure;
      return;
    }

    // FAIL CLOSED: without a VERIFIED gateway payment we do NOT fabricate a
    // transaction ref, do NOT call confirm, and do NOT claim success. The intent
    // exists server-side but the parent is never shown a receipt for an
    // uncollected charge. This is the current path (no SDK wired).
    if (gatewayPayment == null) {
      ref.read(parentPaymentPhaseProvider.notifier).state =
          PaymentFlowPhase.pendingGatewayVerification;
      return;
    }

    final confirmation = await ref
        .read(confirmParentPaymentProvider.notifier)
        .execute(
          ParentPaymentConfirmRequest(
            paymentIntentId: initiation.paymentIntentId,
            // Real gateway reference — the verified payment id, not a fabricated
            // timestamp.
            transactionRef: gatewayPayment.razorpayPaymentId,
            razorpayPaymentId: gatewayPayment.razorpayPaymentId,
            razorpaySignature: gatewayPayment.razorpaySignature,
          ),
        );

    if (confirmation == null) {
      ref.read(parentPaymentPhaseProvider.notifier).state =
          PaymentFlowPhase.failure;
      return;
    }

    ref.read(parentPaymentSuccessResultProvider.notifier).state =
        PaymentSuccessResult(
      receiptId: confirmation.receiptId,
      receiptNumber: confirmation.receiptNumber,
      paidAmount: confirmation.paidAmount,
      paymentMethod: method,
      paidAtLabel: confirmation.paidAtLabel,
    );
    ref.read(parentPaymentPhaseProvider.notifier).state =
        PaymentFlowPhase.success;
  } catch (_) {
    ref.read(parentPaymentPhaseProvider.notifier).state =
        PaymentFlowPhase.failure;
  }
}

void resetPaymentFlow(WidgetRef ref) {
  ref.read(parentPaymentPhaseProvider.notifier).state = PaymentFlowPhase.summary;
  ref.read(parentPaymentSuccessResultProvider.notifier).state = null;
  ref.read(parentPaymentSimulateFailureProvider.notifier).state = false;
}
