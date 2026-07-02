import '../../../../../features/notifications/notifications_models.dart';
import '../../../interfaces/communication_repository.dart';

class CommunicationNotificationDto {
  const CommunicationNotificationDto({required this.raw});

  factory CommunicationNotificationDto.fromJson(Map<String, dynamic> json) {
    return CommunicationNotificationDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class CommunicationTemplateDto {
  const CommunicationTemplateDto({required this.raw});

  factory CommunicationTemplateDto.fromJson(Map<String, dynamic> json) {
    return CommunicationTemplateDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class CommunicationTemplatesResponseDto {
  const CommunicationTemplatesResponseDto({required this.items});

  factory CommunicationTemplatesResponseDto.fromJson(
      Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const [];
    return CommunicationTemplatesResponseDto(
      items: [
        for (final item in items)
          CommunicationTemplateDto.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  final List<CommunicationTemplateDto> items;
}

class CommunicationNotificationsResponseDto {
  const CommunicationNotificationsResponseDto({required this.items});

  factory CommunicationNotificationsResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final items = json['items'] as List<dynamic>? ?? const [];
    return CommunicationNotificationsResponseDto(
      items: [
        for (final item in items)
          CommunicationNotificationDto.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  final List<CommunicationNotificationDto> items;
}

class BroadcastResponseDto {
  const BroadcastResponseDto({required this.raw});

  factory BroadcastResponseDto.fromJson(Map<String, dynamic> json) {
    return BroadcastResponseDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class BroadcastHistoryResponseDto {
  const BroadcastHistoryResponseDto({required this.items});

  factory BroadcastHistoryResponseDto.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const [];
    return BroadcastHistoryResponseDto(
      items: [for (final item in items) item as Map<String, dynamic>],
    );
  }

  final List<Map<String, dynamic>> items;
}

class BroadcastReportResponseDto {
  const BroadcastReportResponseDto({required this.raw});

  factory BroadcastReportResponseDto.fromJson(Map<String, dynamic> json) {
    return BroadcastReportResponseDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class ResendBroadcastResponseDto {
  const ResendBroadcastResponseDto({required this.raw});

  factory ResendBroadcastResponseDto.fromJson(Map<String, dynamic> json) {
    return ResendBroadcastResponseDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class AudienceSegmentDto {
  const AudienceSegmentDto({required this.raw});

  factory AudienceSegmentDto.fromJson(Map<String, dynamic> json) {
    return AudienceSegmentDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class AudienceSegmentsResponseDto {
  const AudienceSegmentsResponseDto({required this.items});

  factory AudienceSegmentsResponseDto.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const [];
    return AudienceSegmentsResponseDto(
      items: [
        for (final item in items)
          AudienceSegmentDto.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  final List<AudienceSegmentDto> items;
}

class CreateAudienceSegmentRequestDto {
  const CreateAudienceSegmentRequestDto({required this.raw});

  factory CreateAudienceSegmentRequestDto.fromArgs({
    required String name,
    required String audienceType,
    String? className,
    String? sectionName,
  }) {
    return CreateAudienceSegmentRequestDto(
      raw: {
        'name': name,
        'audience_type': audienceType,
        if (className != null && className.isNotEmpty) 'class_name': className,
        if (sectionName != null && sectionName.isNotEmpty)
          'section_name': sectionName,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class BroadcastRequestDto {
  const BroadcastRequestDto({required this.raw});

  factory BroadcastRequestDto.fromDomain(BroadcastRequest request) {
    return BroadcastRequestDto(
      raw: {
        'audience': request.audience,
        'title': request.title,
        'body': request.body,
        if (request.audienceClass != null && request.audienceClass!.isNotEmpty)
          'audience_class': request.audienceClass,
        if (request.audienceSection != null &&
            request.audienceSection!.isNotEmpty)
          'audience_section': request.audienceSection,
        if (request.requiresAck) 'requires_ack': true,
        if (request.scheduledAt != null && request.scheduledAt!.isNotEmpty)
          'scheduled_at': request.scheduledAt,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class CreateCommunicationTemplateRequestDto {
  const CreateCommunicationTemplateRequestDto({required this.raw});

  factory CreateCommunicationTemplateRequestDto.fromDomain(
    CreateCommunicationTemplateRequest request,
  ) {
    return CreateCommunicationTemplateRequestDto(
      raw: {
        'code': request.code,
        'channel': request.channel,
        if (request.subjectTemplate != null)
          'subject_template': request.subjectTemplate,
        'body_template': request.bodyTemplate,
        'variables': request.variables,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class UpdateCommunicationTemplateRequestDto {
  const UpdateCommunicationTemplateRequestDto({required this.raw});

  factory UpdateCommunicationTemplateRequestDto.fromDomain(
    UpdateCommunicationTemplateRequest request,
  ) {
    return UpdateCommunicationTemplateRequestDto(
      raw: {
        if (request.code != null) 'code': request.code,
        if (request.channel != null) 'channel': request.channel,
        if (request.subjectTemplate != null)
          'subject_template': request.subjectTemplate,
        if (request.bodyTemplate != null) 'body_template': request.bodyTemplate,
        if (request.variables != null) 'variables': request.variables,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class CommunicationMapper {
  AppNotification toNotification(CommunicationNotificationDto dto) {
    final raw = dto.raw;
    return AppNotification(
      id: raw['id'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      preview: raw['preview'] as String? ?? '',
      timestamp: DateTime.tryParse(raw['timestamp'] as String? ?? '') ??
          DateTime.now(),
      category: _category(raw['category'] as String?),
      isRead: raw['isRead'] as bool? ?? false,
      isUrgent: raw['isUrgent'] as bool? ?? false,
      childContext: raw['childContext'] as String?,
      requiresAck: raw['requiresAck'] as bool? ?? false,
      acknowledgedAt: DateTime.tryParse(raw['acknowledgedAt'] as String? ?? ''),
    );
  }

  CommunicationTemplate toTemplate(CommunicationTemplateDto dto) {
    final raw = dto.raw;
    final vars = raw['variables'];
    return CommunicationTemplate(
      id: raw['id'] as String? ?? '',
      code: raw['code'] as String? ?? '',
      channel: raw['channel'] as String? ?? 'push',
      subjectTemplate: raw['subjectTemplate'] as String? ??
          raw['subject_template'] as String?,
      bodyTemplate: raw['bodyTemplate'] as String? ??
          raw['body_template'] as String? ??
          '',
      variables: vars is List ? [for (final v in vars) v.toString()] : const [],
    );
  }

  BroadcastResult toBroadcastResult(BroadcastResponseDto dto) {
    final raw = dto.raw;
    return BroadcastResult(
      broadcastId: raw['broadcastId'] as String? ?? '',
      recipientCount: raw['recipientCount'] as int? ?? 0,
      status: raw['status'] as String? ?? 'sent',
    );
  }

  BroadcastHistoryItem toBroadcastHistoryItem(Map<String, dynamic> raw) {
    return BroadcastHistoryItem(
      id: raw['id'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      audience: raw['audience'] as String? ?? '',
      status: raw['status'] as String? ?? 'queued',
      recipientCount: raw['recipientCount'] as int? ?? 0,
      sentAt:
          DateTime.tryParse(raw['sentAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  BroadcastDeliveryReport toBroadcastReport(BroadcastReportResponseDto dto) {
    final raw = dto.raw;
    final broadcast = raw['broadcast'] as Map<String, dynamic>? ?? const {};
    final counts = raw['counts'] as Map<String, dynamic>? ?? const {};
    final unread = raw['unreadRecipients'] as List<dynamic>? ?? const [];
    return BroadcastDeliveryReport(
      id: broadcast['id'] as String? ?? '',
      title: broadcast['title'] as String? ?? '',
      audience: broadcast['audience'] as String? ?? '',
      status: broadcast['status'] as String? ?? '',
      requiresAck: broadcast['requiresAck'] as bool? ?? false,
      sentAt: DateTime.tryParse(broadcast['sentAt'] as String? ?? ''),
      scheduledAt: DateTime.tryParse(broadcast['scheduledAt'] as String? ?? ''),
      counts: BroadcastDeliveryCounts(
        total: _asInt(counts['total']),
        sent: _asInt(counts['sent']),
        failed: _asInt(counts['failed']),
        pending: _asInt(counts['pending']),
        read: _asInt(counts['read']),
        unread: _asInt(counts['unread']),
        acknowledged: _asInt(counts['acknowledged']),
      ),
      unreadRecipients: [
        for (final r in unread)
          if (r is Map<String, dynamic>)
            UnreadRecipient(
              userId: r['userId'] as String? ?? '',
              name: r['name'] as String? ?? '',
            ),
      ],
    );
  }

  int toResendCount(ResendBroadcastResponseDto dto) {
    return _asInt(dto.raw['resent']);
  }

  AudienceSegment toAudienceSegment(AudienceSegmentDto dto) {
    final raw = dto.raw;
    return AudienceSegment(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      audienceType: raw['audienceType'] as String? ??
          raw['audience_type'] as String? ??
          '',
      className: raw['className'] as String? ?? raw['class_name'] as String?,
      sectionName:
          raw['sectionName'] as String? ?? raw['section_name'] as String?,
    );
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  NotificationCategory _category(String? value) {
    return switch (value) {
      'fee' => NotificationCategory.fee,
      'attendance' => NotificationCategory.attendance,
      'academic' => NotificationCategory.academic,
      'transport' => NotificationCategory.transport,
      'hostel' => NotificationCategory.hostel,
      'approval' => NotificationCategory.approval,
      'system' => NotificationCategory.system,
      _ => NotificationCategory.announcement,
    };
  }
}
