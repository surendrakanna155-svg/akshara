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
