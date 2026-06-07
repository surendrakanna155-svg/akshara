import '../../../../../features/finance/finance_requests.dart';

class ApproveRefundRequestDto {
  const ApproveRefundRequestDto({required this.raw});

  factory ApproveRefundRequestDto.fromDomain(ApproveRefundRequest request) {
    return ApproveRefundRequestDto(
      raw: {
        'approver': request.approver,
        if (request.comment.isNotEmpty) 'comment': request.comment,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
