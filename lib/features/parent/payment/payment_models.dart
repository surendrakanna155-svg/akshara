import 'package:flutter/material.dart';

/// Supported mock payment channels for PA-10.
enum PaymentMethod { upi, card, netBanking }

extension PaymentMethodX on PaymentMethod {
  String get label {
    return switch (this) {
      PaymentMethod.upi => 'UPI',
      PaymentMethod.card => 'Card',
      PaymentMethod.netBanking => 'Net Banking',
    };
  }

  IconData get icon {
    return switch (this) {
      PaymentMethod.upi => Icons.qr_code_2_outlined,
      PaymentMethod.card => Icons.credit_card_outlined,
      PaymentMethod.netBanking => Icons.account_balance_outlined,
    };
  }
}

/// Payment flow phases rendered by [ParentPaymentScreen].
///
/// [pendingGatewayVerification] (PRA-P0-02, client half) is the fail-closed
/// terminal state reached when a payment intent was created but there is no
/// VERIFIED gateway payment to confirm it — because no payment-gateway SDK is
/// wired yet (an explicit OWNER decision, out of scope). The flow lands here
/// instead of fabricating a receipt and claiming [success] for money that no
/// real gateway ever took.
enum PaymentFlowPhase {
  summary,
  processing,
  pendingGatewayVerification,
  success,
  failure,
}

/// Verified proof of a completed gateway charge, as it would be handed back by
/// a real payment-gateway SDK callback (Razorpay `payment_id` + `signature`).
///
/// PRA-P0-02 (client half): a [success] is only allowed when a value of this
/// type is present. No SDK is wired yet, so in the current build this is always
/// null at the call site — the flow stops at
/// [PaymentFlowPhase.pendingGatewayVerification]. Integrating a real gateway SDK
/// (the sole producer of this proof) remains an explicit OWNER decision.
@immutable
class VerifiedGatewayPayment {
  const VerifiedGatewayPayment({
    required this.razorpayPaymentId,
    required this.razorpaySignature,
  });

  final String razorpayPaymentId;
  final String razorpaySignature;
}

/// Amount line in the payment breakdown.
@immutable
class PaymentBreakdownLine {
  const PaymentBreakdownLine({
    required this.label,
    required this.amount,
  });

  final String label;
  final int amount;
}

/// Payment summary payload for PA-10.
@immutable
class PaymentSummary {
  const PaymentSummary({
    required this.installmentId,
    required this.installmentTitle,
    required this.childName,
    required this.childClass,
    required this.dueLabel,
    required this.baseAmount,
    required this.lateFee,
    required this.convenienceFee,
    required this.breakdown,
    this.unreadNotifications = 0,
  });

  final String installmentId;
  final String installmentTitle;
  final String childName;
  final String childClass;
  final String dueLabel;
  final int baseAmount;
  final int lateFee;
  final int convenienceFee;
  final List<PaymentBreakdownLine> breakdown;
  final int unreadNotifications;

  int get totalAmount => baseAmount + lateFee + convenienceFee;
}

/// Result returned when a payment intent is created.
@immutable
class PaymentInitiationResult {
  const PaymentInitiationResult({
    required this.paymentIntentId,
    required this.installmentId,
    required this.amount,
    required this.status,
    this.expiresAtLabel,
  });

  final String paymentIntentId;
  final String installmentId;
  final int amount;
  final String status;
  final String? expiresAtLabel;
}

/// Result returned after payment gateway confirmation.
@immutable
class PaymentConfirmationResult {
  const PaymentConfirmationResult({
    required this.receiptId,
    required this.receiptNumber,
    required this.paidAmount,
    required this.paymentMethod,
    required this.paidAtLabel,
  });

  final String receiptId;
  final String receiptNumber;
  final int paidAmount;
  final PaymentMethod paymentMethod;
  final String paidAtLabel;
}

/// Result shown after a successful mock payment.
@immutable
class PaymentSuccessResult {
  const PaymentSuccessResult({
    required this.receiptId,
    required this.receiptNumber,
    required this.paidAmount,
    required this.paymentMethod,
    required this.paidAtLabel,
  });

  final String receiptId;
  final String receiptNumber;
  final int paidAmount;
  final PaymentMethod paymentMethod;
  final String paidAtLabel;
}
