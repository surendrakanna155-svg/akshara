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

/// PRI-1 — request body for POST /approvals/batch-decide.
class BatchDecideApprovalsRequestDto {
  const BatchDecideApprovalsRequestDto({
    required this.ids,
    required this.decision,
    this.comment,
  });

  final List<String> ids;

  /// Wire value: 'approve' | 'reject'.
  final String decision;
  final String? comment;

  Map<String, dynamic> toJson() => {
        'ids': ids,
        'decision': decision,
        if (comment != null) 'comment': comment,
      };
}

/// PRI-1 — { decided: [{id, status}], skipped: [{id, reason}] }.
class BatchDecisionResultDto {
  const BatchDecisionResultDto({
    required this.decided,
    required this.skipped,
  });

  factory BatchDecisionResultDto.fromJson(Map<String, dynamic> json) {
    final decidedRaw = json['decided'] as List<dynamic>? ?? const [];
    final skippedRaw = json['skipped'] as List<dynamic>? ?? const [];
    return BatchDecisionResultDto(
      decided: [
        for (final row in decidedRaw)
          if (row is Map<String, dynamic>)
            BatchDecidedItemDto(
              id: row['id'] as String? ?? '',
              status: row['status'] as String? ?? '',
            ),
      ],
      skipped: [
        for (final row in skippedRaw)
          if (row is Map<String, dynamic>)
            BatchSkippedItemDto(
              id: row['id'] as String? ?? '',
              reason: row['reason'] as String? ?? '',
            ),
      ],
    );
  }

  final List<BatchDecidedItemDto> decided;
  final List<BatchSkippedItemDto> skipped;
}

class BatchDecidedItemDto {
  const BatchDecidedItemDto({required this.id, required this.status});

  final String id;
  final String status;
}

class BatchSkippedItemDto {
  const BatchSkippedItemDto({required this.id, required this.reason});

  final String id;
  final String reason;
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
