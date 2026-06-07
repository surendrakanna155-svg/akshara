import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'payment_models.dart';

/// Selected installment id (from route query).
final parentPaymentInstallmentIdProvider = StateProvider<String>(
  (ref) => 'term_2',
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
  return ref.read(parentRepositoryProvider).getPaymentSummary(
        query: ref.watch(repositoryQueryProvider),
        installmentId: installmentId,
      );
});

/// Payment summary derived from installment id.
final parentPaymentSummaryProvider = Provider<PaymentSummary>((ref) {
  final installmentId = ref.watch(parentPaymentInstallmentIdProvider);
  final hasError = ref.watch(parentPaymentErrorProvider);

  if (hasError) {
    throw StateError('Payment summary unavailable');
  }

  final async = ref.watch(parentPaymentSummaryFutureProvider(installmentId));
  final data = watchRepositoryFuture(
    ref,
    async,
    manualLoading: ref.watch(parentPaymentLoadingProvider),
    manualError: ref.watch(parentPaymentErrorProvider),
    manualEmpty: ref.watch(parentPaymentEmptyProvider),
  );
  return data ?? async.value ?? _fallbackSummary(installmentId);
});

PaymentSummary _fallbackSummary(String installmentId) {
  return switch (installmentId) {
    'term_1' => const PaymentSummary(
        installmentId: 'term_1',
        installmentTitle: 'Term 1',
        childName: 'Ravi Kumar',
        childClass: '8-A',
        dueLabel: 'Paid 15 Apr 2026',
        baseAmount: 8000,
        lateFee: 0,
        convenienceFee: 0,
        breakdown: [
          PaymentBreakdownLine(label: 'Tuition', amount: 6500),
          PaymentBreakdownLine(label: 'Transport', amount: 1000),
          PaymentBreakdownLine(label: 'Activity', amount: 500),
        ],
      ),
    _ => const PaymentSummary(
        installmentId: 'term_2',
        installmentTitle: 'Term 2',
        childName: 'Ravi Kumar',
        childClass: '8-A',
        dueLabel: 'Due 12 Jun 2026',
        baseAmount: 4000,
        lateFee: 200,
        convenienceFee: 0,
        unreadNotifications: 2,
        breakdown: [
          PaymentBreakdownLine(label: 'Tuition', amount: 3200),
          PaymentBreakdownLine(label: 'Transport', amount: 600),
          PaymentBreakdownLine(label: 'Activity', amount: 200),
          PaymentBreakdownLine(label: 'Late fee', amount: 200),
        ],
      ),
  };
}

/// Resets flow and kicks off mock payment processing.
Future<void> submitMockPayment(WidgetRef ref) async {
  ref.read(parentPaymentPhaseProvider.notifier).state =
      PaymentFlowPhase.processing;

  await Future<void>.delayed(const Duration(milliseconds: 1200));

  if (ref.read(parentPaymentSimulateFailureProvider)) {
    ref.read(parentPaymentPhaseProvider.notifier).state =
        PaymentFlowPhase.failure;
    return;
  }

  final summary = ref.read(parentPaymentSummaryProvider);
  final method = ref.read(parentPaymentMethodProvider);

  ref.read(parentPaymentSuccessResultProvider.notifier).state =
      PaymentSuccessResult(
    receiptId: 'rcpt_${summary.installmentId}',
    receiptNumber: 'APS-2026-${summary.installmentId.toUpperCase()}',
    paidAmount: summary.totalAmount,
    paymentMethod: method,
    paidAtLabel: '5 Jun 2026 · 10:42 AM',
  );
  ref.read(parentPaymentPhaseProvider.notifier).state = PaymentFlowPhase.success;
}

void resetPaymentFlow(WidgetRef ref) {
  ref.read(parentPaymentPhaseProvider.notifier).state = PaymentFlowPhase.summary;
  ref.read(parentPaymentSuccessResultProvider.notifier).state = null;
  ref.read(parentPaymentSimulateFailureProvider.notifier).state = false;
}
