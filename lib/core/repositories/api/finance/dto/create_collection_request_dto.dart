import '../../../../../features/finance/finance_requests.dart';

class CreateCollectionRequestDto {
  const CreateCollectionRequestDto({required this.raw});

  factory CreateCollectionRequestDto.fromDomain(CreateCollectionRequest request) {
    final amount = double.tryParse(
          request.amountCollected.replaceAll(RegExp(r'[₹,\s]'), ''),
        ) ??
        request.amountCollected;
    return CreateCollectionRequestDto(
      raw: {
        'invoice_id': request.invoiceId,
        'invoiceId': request.invoiceId,
        'amount_collected': amount,
        'amountCollected': amount,
        'payment_method': request.paymentMethod,
        'paymentMethod': request.paymentMethod,
        if (request.referenceNumber != null)
          'reference_number': request.referenceNumber,
        if (request.referenceNumber != null)
          'referenceNumber': request.referenceNumber,
        if (request.notes != null) 'notes': request.notes,
        if (request.collectionDate != null)
          'collection_date': request.collectionDate,
        if (request.collectionDate != null)
          'collectionDate': request.collectionDate,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class FinanceCollectionResultDto {
  const FinanceCollectionResultDto({required this.raw});

  factory FinanceCollectionResultDto.fromJson(Map<String, dynamic> json) {
    return FinanceCollectionResultDto(raw: json);
  }

  final Map<String, dynamic> raw;
}
