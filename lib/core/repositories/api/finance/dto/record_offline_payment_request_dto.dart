import '../../../../../features/finance/finance_requests.dart';
import 'finance_enum_codec.dart';

class RecordOfflinePaymentRequestDto {
  const RecordOfflinePaymentRequestDto({required this.raw});

  factory RecordOfflinePaymentRequestDto.fromDomain(
    RecordOfflinePaymentRequest request,
  ) {
    final amount =
        double.tryParse(request.amount.replaceAll(RegExp(r'[₹,\s]'), '')) ??
            request.amount;
    final method = FinanceEnumCodec.offlinePaymentMethodToApi(request.method);
    return RecordOfflinePaymentRequestDto(
      raw: {
        'invoice_id': request.invoiceId,
        'invoiceId': request.invoiceId,
        'student_name': request.studentName,
        'studentName': request.studentName,
        'amount': amount,
        'payment_method': method,
        'paymentMethod': method,
        'reference_number': request.referenceNumber,
        'referenceNumber': request.referenceNumber,
        if (request.instrumentDate != null) ...{
          'instrument_date': request.instrumentDate,
          'instrumentDate': request.instrumentDate,
        },
        if (request.bankName != null) ...{
          'bank_name': request.bankName,
          'bankName': request.bankName,
        },
        'recorded_at': request.recordedAt,
        'recordedAt': request.recordedAt,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
