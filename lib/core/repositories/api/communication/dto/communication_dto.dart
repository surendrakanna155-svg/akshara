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

class BroadcastRequestDto {
  const BroadcastRequestDto({required this.raw});

  factory BroadcastRequestDto.fromDomain(BroadcastRequest request) {
    return BroadcastRequestDto(
      raw: {
        'audience': request.audience,
        'title': request.title,
        'body': request.body,
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
