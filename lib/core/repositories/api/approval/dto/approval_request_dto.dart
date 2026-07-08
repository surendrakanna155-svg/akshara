/// Wire DTO for a single approval request row.
class ApprovalRequestDto {
  const ApprovalRequestDto({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.summary,
    required this.requesterId,
    required this.requesterName,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.payload = const {},
    this.decidedAt,
    this.decidedById,
    this.decidedByName,
    this.decisionComment,
    this.tenantId,
    this.schoolId,
    this.sodBlocked = false,
  });

  factory ApprovalRequestDto.fromJson(Map<String, dynamic> json) {
    return ApprovalRequestDto(
      id: json['id'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      requesterId: json['requesterId'] as String? ?? json['requester_id'] as String,
      requesterName: json['requesterName'] as String? ?? json['requester_name'] as String,
      entityType: json['entityType'] as String? ?? json['entity_type'] as String,
      entityId: json['entityId'] as String? ?? json['entity_id'] as String,
      payload: _payload(json['payload']),
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String,
      decidedAt: json['decidedAt'] as String? ?? json['decided_at'] as String?,
      decidedById: json['decidedById'] as String? ?? json['decided_by_id'] as String?,
      decidedByName:
          json['decidedByName'] as String? ?? json['decided_by_name'] as String?,
      decisionComment:
          json['decisionComment'] as String? ?? json['decision_comment'] as String?,
      tenantId: json['tenantId'] as String? ?? json['organization_id'] as String?,
      schoolId: json['schoolId'] as String? ?? json['school_id'] as String?,
      sodBlocked: (json['sodBlocked'] ?? json['sod_blocked']) as bool? ?? false,
    );
  }

  final String id;
  final String type;
  final String status;
  final String title;
  final String summary;
  final String requesterId;
  final String requesterName;
  final String entityType;
  final String entityId;
  final Map<String, Object?> payload;
  final String createdAt;
  final String? decidedAt;
  final String? decidedById;
  final String? decidedByName;
  final String? decisionComment;
  final String? tenantId;
  final String? schoolId;
  final bool sodBlocked;

  static Map<String, Object?> _payload(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return Map<String, Object?>.from(raw);
    }
    return const {};
  }
}

class ApprovalRequestsResponseDto {
  const ApprovalRequestsResponseDto({required this.items});

  factory ApprovalRequestsResponseDto.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? const [];
    return ApprovalRequestsResponseDto(
      items: [
        for (final item in itemsRaw)
          if (item is Map<String, dynamic>) ApprovalRequestDto.fromJson(item),
      ],
    );
  }

  final List<ApprovalRequestDto> items;
}
