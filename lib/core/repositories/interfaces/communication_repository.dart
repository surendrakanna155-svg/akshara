import '../../../features/notifications/notifications_models.dart';
import '../repository_query.dart';

/// Communication Hub read/write contract (notifications, broadcasts, templates).
abstract class CommunicationRepository {
  Future<List<AppNotification>> getNotifications({
    required RepositoryQuery query,
  });

  Future<void> markNotificationRead({
    required RepositoryQuery query,
    required String notificationId,
  });

  Future<void> markAllNotificationsRead({
    required RepositoryQuery query,
  });

  Future<void> registerDeviceToken({
    required RepositoryQuery query,
    required String platform,
    required String token,
  });

  Future<void> unregisterDeviceToken({
    required RepositoryQuery query,
    required String token,
  });

  Future<List<CommunicationTemplate>> getTemplates({
    required RepositoryQuery query,
  });

  Future<CommunicationTemplate> createTemplate({
    required RepositoryQuery query,
    required CreateCommunicationTemplateRequest request,
  });

  Future<CommunicationTemplate> updateTemplate({
    required RepositoryQuery query,
    required String templateId,
    required UpdateCommunicationTemplateRequest request,
  });

  Future<List<BroadcastHistoryItem>> listBroadcastHistory({
    required RepositoryQuery query,
  });

  Future<BroadcastResult> sendBroadcast({
    required RepositoryQuery query,
    required BroadcastRequest request,
  });
}

class CommunicationTemplate {
  const CommunicationTemplate({
    required this.id,
    required this.code,
    required this.channel,
    required this.bodyTemplate,
    this.subjectTemplate,
    this.variables = const [],
  });

  final String id;
  final String code;
  final String channel;
  final String? subjectTemplate;
  final String bodyTemplate;
  final List<String> variables;
}

class BroadcastRequest {
  const BroadcastRequest({
    required this.audience,
    required this.title,
    required this.body,
  });

  final String audience;
  final String title;
  final String body;
}

class BroadcastResult {
  const BroadcastResult({
    required this.broadcastId,
    required this.recipientCount,
    required this.status,
  });

  final String broadcastId;
  final int recipientCount;
  final String status;
}

class CreateCommunicationTemplateRequest {
  const CreateCommunicationTemplateRequest({
    required this.code,
    required this.channel,
    this.subjectTemplate,
    required this.bodyTemplate,
    this.variables = const [],
  });

  final String code;
  final String channel;
  final String? subjectTemplate;
  final String bodyTemplate;
  final List<String> variables;
}

class UpdateCommunicationTemplateRequest {
  const UpdateCommunicationTemplateRequest({
    this.code,
    this.channel,
    this.subjectTemplate,
    this.bodyTemplate,
    this.variables,
  });

  final String? code;
  final String? channel;
  final String? subjectTemplate;
  final String? bodyTemplate;
  final List<String>? variables;
}

class BroadcastHistoryItem {
  const BroadcastHistoryItem({
    required this.id,
    required this.title,
    required this.audience,
    required this.status,
    required this.recipientCount,
    required this.sentAt,
  });

  final String id;
  final String title;
  final String audience;
  final String status;
  final int recipientCount;
  final DateTime sentAt;
}
