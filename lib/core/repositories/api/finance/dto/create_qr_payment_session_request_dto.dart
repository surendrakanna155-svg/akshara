import '../../../../../features/finance/finance_requests.dart';

class CreateQrPaymentSessionRequestDto {
  const CreateQrPaymentSessionRequestDto({required this.raw});

  factory CreateQrPaymentSessionRequestDto.fromDomain(
    CreateQrPaymentSessionRequest request,
  ) {
    final amount = request.amount.trim();
    return CreateQrPaymentSessionRequestDto(
      raw: {
        'invoice_id': request.invoiceId,
        'invoiceId': request.invoiceId,
        'amount': amount,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
