import '../../../../../features/parent/parent_requests.dart';
import '../../../../../features/parent/payment/payment_models.dart';

class ParentPaymentInitiateRequestDto {
  const ParentPaymentInitiateRequestDto({required this.raw});

  factory ParentPaymentInitiateRequestDto.fromDomain(
    ParentPaymentInitiateRequest request,
  ) {
    return ParentPaymentInitiateRequestDto(
      raw: {
        'installment_id': request.installmentId,
        'payment_method': _paymentMethodToApi(request.paymentMethod),
        'amount': request.amount,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;

  static String _paymentMethodToApi(PaymentMethod method) => switch (method) {
        PaymentMethod.upi => 'upi',
        PaymentMethod.card => 'card',
        PaymentMethod.netBanking => 'net_banking',
      };
}

class ParentPaymentConfirmRequestDto {
  const ParentPaymentConfirmRequestDto({required this.raw});

  factory ParentPaymentConfirmRequestDto.fromDomain(
    ParentPaymentConfirmRequest request,
  ) {
    return ParentPaymentConfirmRequestDto(
      raw: {
        'payment_intent_id': request.paymentIntentId,
        'transaction_ref': request.transactionRef,
        // PRA-P0-02 (client half): forward the VERIFIED gateway proof under the
        // exact snake_case keys `payment_service.ts` reads in its live
        // verification path (`razorpay_payment_id` / `razorpay_signature`). Only
        // emitted when present, so the contract is ready the moment a real
        // gateway SDK supplies them; today they are absent (no SDK wired).
        if (request.razorpayPaymentId != null)
          'razorpay_payment_id': request.razorpayPaymentId,
        if (request.razorpaySignature != null)
          'razorpay_signature': request.razorpaySignature,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class ParentPaymentInitiationResponseDto {
  const ParentPaymentInitiationResponseDto({required this.raw});

  factory ParentPaymentInitiationResponseDto.fromJson(Map<String, dynamic> json) {
    return ParentPaymentInitiationResponseDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class ParentPaymentConfirmationResponseDto {
  const ParentPaymentConfirmationResponseDto({required this.raw});

  factory ParentPaymentConfirmationResponseDto.fromJson(Map<String, dynamic> json) {
    return ParentPaymentConfirmationResponseDto(raw: json);
  }

  final Map<String, dynamic> raw;
}
