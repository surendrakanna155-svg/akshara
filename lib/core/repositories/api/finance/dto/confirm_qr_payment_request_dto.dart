import '../../../../../features/finance/finance_requests.dart';

class ConfirmQrPaymentRequestDto {
  const ConfirmQrPaymentRequestDto({required this.raw});

  factory ConfirmQrPaymentRequestDto.fromDomain(
      ConfirmQrPaymentRequest request) {
    return ConfirmQrPaymentRequestDto(
      raw: {
        if (request.receiptNumber != null &&
            request.receiptNumber!.trim().isNotEmpty)
          'receipt_number': request.receiptNumber!.trim(),
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
