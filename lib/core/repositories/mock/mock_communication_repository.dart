import '../../../features/notifications/notifications_models.dart';
import '../../communication/school_broadcast_store.dart';
import '../interfaces/communication_repository.dart';
import '../repository_query.dart';

class MockCommunicationRepository implements CommunicationRepository {
  final List<CommunicationTemplate> _templates = [
    const CommunicationTemplate(
      id: 'tpl-1',
      code: 'fee_reminder_push',
      channel: 'push',
      subjectTemplate: 'Fee reminder — {{term}}',
      bodyTemplate: '₹{{amount}} due by {{due_date}}.',
      variables: ['term', 'amount', 'due_date'],
    ),
  ];
  final List<BroadcastHistoryItem> _history = [];

  @override
  Future<List<AppNotification>> getNotifications({
    required RepositoryQuery query,
  }) async {
    return [
      AppNotification(
        id: 'nt-mock-1',
        title: 'Fee reminder — Term 2',
        preview: '₹4,200 due by 15 Jun.',
        timestamp: DateTime.now(),
        category: NotificationCategory.fee,
        isUrgent: true,
        childContext: 'Ravi · 8-A',
      ),
    ];
  }

  @override
  Future<void> markNotificationRead({
    required RepositoryQuery query,
    required String notificationId,
  }) async {}

  @override
  Future<void> markAllNotificationsRead({
    required RepositoryQuery query,
  }) async {}

  @override
  Future<void> registerDeviceToken({
    required RepositoryQuery query,
    required String platform,
    required String token,
  }) async {}

  @override
  Future<void> unregisterDeviceToken({
    required RepositoryQuery query,
    required String token,
  }) async {}

  @override
  Future<List<CommunicationTemplate>> getTemplates({
    required RepositoryQuery query,
  }) async {
    return List<CommunicationTemplate>.from(_templates);
  }

  @override
  Future<CommunicationTemplate> createTemplate({
    required RepositoryQuery query,
    required CreateCommunicationTemplateRequest request,
  }) async {
    final template = CommunicationTemplate(
      id: 'tpl-${DateTime.now().millisecondsSinceEpoch}',
      code: request.code,
      channel: request.channel,
      subjectTemplate: request.subjectTemplate,
      bodyTemplate: request.bodyTemplate,
      variables: request.variables,
    );
    _templates.insert(0, template);
    return template;
  }

  @override
  Future<CommunicationTemplate> updateTemplate({
    required RepositoryQuery query,
    required String templateId,
    required UpdateCommunicationTemplateRequest request,
  }) async {
    final index =
        _templates.indexWhere((template) => template.id == templateId);
    if (index < 0) {
      throw StateError('Template not found: $templateId');
    }
    final current = _templates[index];
    final updated = CommunicationTemplate(
      id: current.id,
      code: request.code ?? current.code,
      channel: request.channel ?? current.channel,
      subjectTemplate: request.subjectTemplate ?? current.subjectTemplate,
      bodyTemplate: request.bodyTemplate ?? current.bodyTemplate,
      variables: request.variables ?? current.variables,
    );
    _templates[index] = updated;
    return updated;
  }

  @override
  Future<List<BroadcastHistoryItem>> listBroadcastHistory({
    required RepositoryQuery query,
  }) async {
    return List<BroadcastHistoryItem>.from(_history);
  }

  @override
  Future<BroadcastResult> sendBroadcast({
    required RepositoryQuery query,
    required BroadcastRequest request,
  }) async {
    final sentAt = DateTime.now();
    // Surface the announcement to the targeted audience's notices.
    SchoolBroadcastStore.instance.add(
      title: request.title,
      body: request.body,
      audience: request.audience,
    );
    final result = BroadcastResult(
      broadcastId: 'broadcast-${sentAt.millisecondsSinceEpoch}',
      recipientCount: 42,
      status: 'sent',
    );
    _history.insert(
      0,
      BroadcastHistoryItem(
        id: result.broadcastId,
        title: request.title,
        audience: request.audience,
        status: result.status,
        recipientCount: result.recipientCount,
        sentAt: sentAt,
      ),
    );
    return result;
  }
}
