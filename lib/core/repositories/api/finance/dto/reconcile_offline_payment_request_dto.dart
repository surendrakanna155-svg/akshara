import '../../../../../features/finance/finance_requests.dart';

class ReconcileOfflinePaymentRequestDto {
  const ReconcileOfflinePaymentRequestDto({required this.raw});

  factory ReconcileOfflinePaymentRequestDto.fromDomain(
    ReconcileOfflinePaymentRequest request,
  ) {
    return ReconcileOfflinePaymentRequestDto(
      raw: {
        if (request.reconciledAt != null) 'reconciled_at': request.reconciledAt,
        if (request.reconciledAt != null) 'reconciledAt': request.reconciledAt,
        if (request.notes != null) 'notes': request.notes,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
