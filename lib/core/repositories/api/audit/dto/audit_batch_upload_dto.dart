import '../../../../audit/audit_event.dart';

/// Request body for `POST /audit/events/batch`.
class AuditBatchUploadRequestDto {
  const AuditBatchUploadRequestDto({required this.events});

  factory AuditBatchUploadRequestDto.fromEvents(List<AuditEvent> events) {
    return AuditBatchUploadRequestDto(
      events: [
        for (final event in events) AuditEventPayloadDto.fromEvent(event),
      ],
    );
  }

  final List<AuditEventPayloadDto> events;

  Map<String, dynamic> toJson() => {
        'events': [for (final event in events) event.toJson()],
      };
}

class AuditEventPayloadDto {
  const AuditEventPayloadDto({
    required this.id,
    required this.type,
    required this.timestamp,
    this.userId,
    this.tenantId,
    this.schoolId,
    this.correlationId,
    this.category,
    this.metadata = const {},
  });

  factory AuditEventPayloadDto.fromEvent(AuditEvent event) {
    return AuditEventPayloadDto(
      id: event.id,
      type: event.type.name,
      timestamp: event.timestamp.toIso8601String(),
      userId: event.userId,
      tenantId: event.tenantId,
      schoolId: event.schoolId,
      correlationId: event.correlationId,
      category: event.resolvedCategory.name,
      metadata: event.metadata,
    );
  }

  final String id;
  final String type;
  final String timestamp;
  final String? userId;
  final String? tenantId;
  final String? schoolId;
  final String? correlationId;
  final String? category;
  final Map<String, String> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'timestamp': timestamp,
        if (userId != null) 'userId': userId,
        if (tenantId != null) 'tenantId': tenantId,
        if (schoolId != null) 'schoolId': schoolId,
        if (correlationId != null) 'correlationId': correlationId,
        if (category != null) 'category': category,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

/// Response body from `POST /audit/events/batch`.
class AuditBatchUploadResponseDto {
  const AuditBatchUploadResponseDto({
    required this.acceptedCount,
    this.rejectedIds = const [],
  });

  factory AuditBatchUploadResponseDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return AuditBatchUploadResponseDto(
      acceptedCount: data['acceptedCount'] as int? ?? 0,
      rejectedIds: [
        for (final id in data['rejectedIds'] as List? ?? const [])
          if (id is String) id,
      ],
    );
  }

  final int acceptedCount;
  final List<String> rejectedIds;
}
