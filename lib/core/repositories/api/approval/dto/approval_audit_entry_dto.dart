/// Wire DTO for approval audit trail entries.
class ApprovalAuditEntryDto {
  const ApprovalAuditEntryDto({
    required this.id,
    required this.approvalRequestId,
    required this.action,
    required this.actorId,
    required this.actorName,
    required this.occurredAt,
    this.comment,
    this.tenantId,
    this.schoolId,
    this.metadata = const {},
  });

  factory ApprovalAuditEntryDto.fromJson(Map<String, dynamic> json) {
    final metadataRaw = json['metadata'];
    final metadata = <String, String>{};
    if (metadataRaw is Map) {
      for (final entry in metadataRaw.entries) {
        metadata['${entry.key}'] = '${entry.value}';
      }
    }

    return ApprovalAuditEntryDto(
      id: json['id'] as String,
      approvalRequestId: json['approvalRequestId'] as String? ??
          json['approval_request_id'] as String,
      action: json['action'] as String,
      actorId: json['actorId'] as String? ?? json['actor_id'] as String,
      actorName: json['actorName'] as String? ?? json['actor_name'] as String,
      occurredAt: json['occurredAt'] as String? ?? json['occurred_at'] as String,
      comment: json['comment'] as String?,
      tenantId: json['tenantId'] as String? ?? json['organization_id'] as String?,
      schoolId: json['schoolId'] as String? ?? json['school_id'] as String?,
      metadata: metadata,
    );
  }

  final String id;
  final String approvalRequestId;
  final String action;
  final String actorId;
  final String actorName;
  final String occurredAt;
  final String? comment;
  final String? tenantId;
  final String? schoolId;
  final Map<String, String> metadata;
}

class ApprovalAuditResponseDto {
  const ApprovalAuditResponseDto({required this.items});

  factory ApprovalAuditResponseDto.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? const [];
    return ApprovalAuditResponseDto(
      items: [
        for (final item in itemsRaw)
          if (item is Map<String, dynamic>) ApprovalAuditEntryDto.fromJson(item),
      ],
    );
  }

  final List<ApprovalAuditEntryDto> items;
}
