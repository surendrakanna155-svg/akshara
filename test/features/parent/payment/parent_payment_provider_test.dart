import 'package:akshara_erp/features/parent/payment/parent_payment_provider.dart';
import 'package:akshara_erp/features/parent/payment/payment_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parentPaymentProvider', () {
    test('returns term 2 payment summary by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final summary = container.read(parentPaymentSummaryProvider);

      expect(summary.installmentTitle, 'Term 2');
      expect(summary.totalAmount, 4200);
      expect(summary.childName, 'Ravi Kumar');
    });

    test('parentPaymentMethodProvider defaults to UPI', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(parentPaymentMethodProvider),
        PaymentMethod.upi,
      );
    });

    test('installment id updates summary payload', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(parentPaymentInstallmentIdProvider.notifier).state =
          'term_1';
      final summary = container.read(parentPaymentSummaryProvider);

      expect(summary.installmentTitle, 'Term 1');
      expect(summary.totalAmount, 8000);
    });

    test('parentPaymentErrorProvider blocks summary read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(parentPaymentErrorProvider.notifier).state = true;

      expect(
        () => container.read(parentPaymentSummaryProvider),
        throwsStateError,
      );
    });
  });
}
