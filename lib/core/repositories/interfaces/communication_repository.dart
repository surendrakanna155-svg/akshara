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

  /// COM-1: per-broadcast delivery & read report (counts + unread roster).
  Future<BroadcastDeliveryReport> getBroadcastReport({
    required RepositoryQuery query,
    required String broadcastId,
  });

  /// COM-3: re-enqueue a broadcast to its unread recipients. Returns the number
  /// of recipients re-targeted (`resent`).
  Future<int> resendBroadcastToUnread({
    required RepositoryQuery query,
    required String broadcastId,
  });

  /// COM-2: list the caller's school's saved audience segments.
  Future<List<AudienceSegment>> listAudienceSegments({
    required RepositoryQuery query,
  });

  /// COM-2: save a named audience segment. Class audiences require [className].
  Future<AudienceSegment> createAudienceSegment({
    required RepositoryQuery query,
    required String name,
    required String audienceType,
    String? className,
    String? sectionName,
  });

  /// COM-2: delete a saved audience segment by id.
  Future<void> deleteAudienceSegment({
    required RepositoryQuery query,
    required String id,
  });

  /// COM-D1: record the caller's acknowledgement of one of their OWN deliveries.
  Future<void> acknowledgeNotification({
    required RepositoryQuery query,
    required String deliveryId,
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
    this.audienceClass,
    this.audienceSection,
    this.requiresAck = false,
    this.scheduledAt,
  });

  final String audience;
  final String title;
  final String body;

  /// COM-2/COM-4: class target for `class_parents` / `class_students`.
  final String? audienceClass;

  /// Optional section within [audienceClass].
  final String? audienceSection;

  /// COM-D1: when true, recipients must acknowledge the notice.
  final bool requiresAck;

  /// COM-4: ISO-8601 send-time. When present the broadcast is SCHEDULED, not sent.
  final String? scheduledAt;
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

/// COM-1: aggregate delivery/read counts for a broadcast report.
class BroadcastDeliveryCounts {
  const BroadcastDeliveryCounts({
    this.total = 0,
    this.sent = 0,
    this.failed = 0,
    this.pending = 0,
    this.read = 0,
    this.unread = 0,
    this.acknowledged = 0,
  });

  final int total;
  final int sent;
  final int failed;
  final int pending;
  final int read;
  final int unread;
  final int acknowledged;
}

/// COM-1: a recipient who has been sent the broadcast but has not read it yet.
class UnreadRecipient {
  const UnreadRecipient({required this.userId, required this.name});

  final String userId;
  final String name;
}

/// COM-1: full per-broadcast delivery & read report (summary + counts + roster).
class BroadcastDeliveryReport {
  const BroadcastDeliveryReport({
    required this.id,
    required this.title,
    required this.audience,
    required this.status,
    required this.counts,
    this.requiresAck = false,
    this.sentAt,
    this.scheduledAt,
    this.unreadRecipients = const [],
  });

  final String id;
  final String title;
  final String audience;
  final String status;
  final bool requiresAck;
  final DateTime? sentAt;
  final DateTime? scheduledAt;
  final BroadcastDeliveryCounts counts;
  final List<UnreadRecipient> unreadRecipients;
}

/// COM-2: a saved audience segment (named, reusable broadcast target).
class AudienceSegment {
  const AudienceSegment({
    required this.id,
    required this.name,
    required this.audienceType,
    this.className,
    this.sectionName,
  });

  final String id;
  final String name;
  final String audienceType;
  final String? className;
  final String? sectionName;
}
