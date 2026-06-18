import '../../../../approvals/approval_request_type.dart';
import '../../../../approvals/approval_requests.dart';

class SubmitApprovalRequestDto {
  const SubmitApprovalRequestDto({
    required this.type,
    required this.title,
    required this.summary,
    required this.requesterId,
    required this.requesterName,
    required this.entityType,
    required this.entityId,
    this.payload = const {},
  });

  factory SubmitApprovalRequestDto.fromDomain(SubmitApprovalRequest request) {
    return SubmitApprovalRequestDto(
      type: request.type.name,
      title: request.title,
      summary: request.summary,
      requesterId: request.requesterId,
      requesterName: request.requesterName,
      entityType: request.entityType,
      entityId: request.entityId,
      payload: request.payload,
    );
  }

  final String type;
  final String title;
  final String summary;
  final String requesterId;
  final String requesterName;
  final String entityType;
  final String entityId;
  final Map<String, Object?> payload;

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'summary': summary,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'entityType': entityType,
        'entityId': entityId,
        'payload': payload,
      };
}

class DecideApprovalRequestDto {
  const DecideApprovalRequestDto({
    required this.actorId,
    required this.actorName,
    this.comment,
  });

  final String actorId;
  final String actorName;
  final String? comment;

  Map<String, dynamic> toJson() => {
        'actorId': actorId,
        'actorName': actorName,
        if (comment != null) 'comment': comment,
      };
}

class ApprovalListFilterQuery {
  const ApprovalListFilterQuery({
    this.status,
    this.type,
    this.requesterId,
    this.entityType,
    this.entityId,
  });

  final String? status;
  final ApprovalRequestType? type;
  final String? requesterId;
  final String? entityType;
  final String? entityId;

  Map<String, dynamic> toQueryParams() => {
        if (status != null) 'status': status,
        if (type != null) 'type': type!.name,
        if (requesterId != null) 'requesterId': requesterId,
        if (entityType != null) 'entityType': entityType,
        if (entityId != null) 'entityId': entityId,
      };
}
