import '../../../../../features/parent/parent_requests.dart';
import '../dto/parent_enum_codec.dart';

class ParentLeaveSubmitRequestDto {
  const ParentLeaveSubmitRequestDto({required this.raw});

  factory ParentLeaveSubmitRequestDto.fromDomain(ParentLeaveSubmitRequest request) {
    return ParentLeaveSubmitRequestDto(
      raw: {
        'child_id': request.childId,
        'from_date_label': request.fromDateLabel,
        'to_date_label': request.toDateLabel,
        'reason': request.reason,
        'type': ParentEnumCodec.leaveTypeToApi(request.type),
        'has_attachment': request.hasAttachment,
        if (request.attachmentName != null) 'attachment_name': request.attachmentName,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
