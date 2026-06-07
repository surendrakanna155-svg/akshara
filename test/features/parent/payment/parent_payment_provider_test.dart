import 'package:akshara_erp/features/parent/payment/parent_payment_provider.dart';
import 'package:akshara_erp/features/parent/payment/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('parentPaymentProvider', () {
    test('returns term 2 payment summary by default', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentPaymentSummaryFutureProvider('term_2').future);
      final summary = container.read(parentPaymentSummaryProvider);

      expect(summary.installmentTitle, 'Term 2');
      expect(summary.totalAmount, 4200);
      expect(summary.childName, 'Ravi Kumar');
    });

    test('parentPaymentMethodProvider defaults to UPI', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      expect(
        container.read(parentPaymentMethodProvider),
        PaymentMethod.upi,
      );
    });

    test('installment id updates summary payload', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(parentPaymentInstallmentIdProvider.notifier).state =
          'term_1';
      await container.read(parentPaymentSummaryFutureProvider('term_1').future);
      final summary = container.read(parentPaymentSummaryProvider);

      expect(summary.installmentTitle, 'Term 1');
      expect(summary.totalAmount, 8000);
    });

    test('parentPaymentErrorProvider blocks summary read', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(parentPaymentErrorProvider.notifier).state = true;

      expect(
        () => container.read(parentPaymentSummaryProvider),
        throwsStateError,
      );
    });
  });
}
