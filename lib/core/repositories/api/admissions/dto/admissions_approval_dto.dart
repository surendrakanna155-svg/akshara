import 'api_envelope_dto.dart';
import 'pagination_dto.dart';

class ApprovalQueueItemDto {
  const ApprovalQueueItemDto({required this.raw});

  factory ApprovalQueueItemDto.fromJson(Map<String, dynamic> json) {
    return ApprovalQueueItemDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class AdmissionsApprovalQueueResponseDto {
  const AdmissionsApprovalQueueResponseDto({
    required this.items,
    this.pagination,
  });

  factory AdmissionsApprovalQueueResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AdmissionsApprovalQueueResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          ApprovalQueueItemDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<ApprovalQueueItemDto> items;
  final PaginationDto? pagination;
}
