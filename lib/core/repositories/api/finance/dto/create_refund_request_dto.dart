import '../../../../../features/finance/finance_requests.dart';

class CreateRefundRequestDto {
  const CreateRefundRequestDto({required this.raw});

  factory CreateRefundRequestDto.fromDomain(CreateRefundRequest request) {
    return CreateRefundRequestDto(
      raw: {
        'fee_account_id': request.feeAccountId,
        'amount': request.amount,
        'reason': request.reason,
        if (request.studentName.isNotEmpty) 'student_name': request.studentName,
        if (request.admissionNumber.isNotEmpty)
          'admission_number': request.admissionNumber,
        if (request.classLabel.isNotEmpty) 'class_label': request.classLabel,
        if (request.originalReceipt.isNotEmpty)
          'original_receipt': request.originalReceipt,
        if (request.collectionId.isNotEmpty)
          'collection_id': request.collectionId,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
