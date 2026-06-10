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

  factory CommunicationTemplatesResponseDto.fromJson(Map<String, dynamic> json) {
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
      subjectTemplate: raw['subjectTemplate'] as String?,
      bodyTemplate: raw['bodyTemplate'] as String? ?? '',
      variables: vars is List
          ? [for (final v in vars) v.toString()]
          : const [],
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
