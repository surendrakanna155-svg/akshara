import 'package:akshara_erp/core/repositories/api/parent/dto/parent_payment_request_dto.dart';
import 'package:akshara_erp/core/repositories/mock/mock_fee_store.dart';
import 'package:akshara_erp/features/parent/parent_requests.dart';
import 'package:akshara_erp/features/parent/payment/parent_payment_provider.dart';
import 'package:akshara_erp/features/parent/payment/payment_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';
import '../../../test_helpers.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  setUp(() {
    MockFeeStore.instance.reset();
  });

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

  // PRA-P0-02 (client half): the payment submit path was previously untested,
  // which is how it shipped fabricating a `txn_<millis>` ref and reporting
  // success with a receipt for money no gateway took. These tests pin the
  // fail-closed contract: no VERIFIED gateway payment => never `success`.
  group('submitParentPayment — PRA-P0-02 fail-closed (client half)', () {
    Future<WidgetRef> pumpCapturingRef(WidgetTester tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: providerTestOverrides(),
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      return capturedRef;
    }

    testWidgets(
      '(a) a confirm WITHOUT a verified gateway id never reaches success '
      '(no fabricated receipt)',
      (tester) async {
        final ref = await pumpCapturingRef(tester);

        await tester.runAsync(() async {
          await ref.read(parentPaymentSummaryFutureProvider('term_2').future);
          // No gatewayPayment: no payment-gateway SDK is wired, so the flow
          // MUST fail closed rather than optimistically confirm.
          await submitParentPayment(ref);
        });
        await tester.pump();

        // Lands on the honest "not verified / not charged" terminal state...
        expect(
          ref.read(parentPaymentPhaseProvider),
          PaymentFlowPhase.pendingGatewayVerification,
        );
        // ...and specifically NEVER on success.
        expect(
          ref.read(parentPaymentPhaseProvider),
          isNot(PaymentFlowPhase.success),
        );
        // No receipt is fabricated / shown.
        expect(ref.read(parentPaymentSuccessResultProvider), isNull);
      },
    );

    testWidgets(
      'a confirm WITH a verified gateway payment reaches success '
      '(the success branch is gated, not removed)',
      (tester) async {
        final ref = await pumpCapturingRef(tester);

        await tester.runAsync(() async {
          await ref.read(parentPaymentSummaryFutureProvider('term_2').future);
          await submitParentPayment(
            ref,
            gatewayPayment: const VerifiedGatewayPayment(
              razorpayPaymentId: 'pay_verified_123',
              razorpaySignature: 'sig_verified_abc',
            ),
          );
        });
        await tester.pump();

        expect(
          ref.read(parentPaymentPhaseProvider),
          PaymentFlowPhase.success,
        );
        expect(ref.read(parentPaymentSuccessResultProvider), isNotNull);
      },
    );

    testWidgets(
      'simulated failure still surfaces failure, not success',
      (tester) async {
        final ref = await pumpCapturingRef(tester);

        ref.read(parentPaymentSimulateFailureProvider.notifier).state = true;
        await tester.runAsync(() async {
          await submitParentPayment(ref);
        });
        await tester.pump();

        expect(
          ref.read(parentPaymentPhaseProvider),
          PaymentFlowPhase.failure,
        );
        expect(ref.read(parentPaymentSuccessResultProvider), isNull);
      },
    );
  });

  // (b) The confirm request/DTO must carry the new optional gateway proof under
  // the exact snake_case keys the backend live-verification path reads
  // (`razorpay_payment_id` / `razorpay_signature`, per payment_service.ts).
  group('ParentPaymentConfirmRequest gateway wiring — PRA-P0-02', () {
    test('DTO carries the gateway proof under the backend snake_case keys', () {
      const request = ParentPaymentConfirmRequest(
        paymentIntentId: 'intent_1',
        transactionRef: 'pay_verified_123',
        razorpayPaymentId: 'pay_verified_123',
        razorpaySignature: 'sig_verified_abc',
      );

      final json = ParentPaymentConfirmRequestDto.fromDomain(request).toJson();

      expect(json['payment_intent_id'], 'intent_1');
      expect(json['transaction_ref'], 'pay_verified_123');
      expect(json['razorpay_payment_id'], 'pay_verified_123');
      expect(json['razorpay_signature'], 'sig_verified_abc');
    });

    test('DTO omits the gateway keys entirely when no proof is present', () {
      const request = ParentPaymentConfirmRequest(
        paymentIntentId: 'intent_1',
        transactionRef: 'txn_ref',
      );

      final json = ParentPaymentConfirmRequestDto.fromDomain(request).toJson();

      expect(json.containsKey('razorpay_payment_id'), isFalse);
      expect(json.containsKey('razorpay_signature'), isFalse);
    });
  });
}
