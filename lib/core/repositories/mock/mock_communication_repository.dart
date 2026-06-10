import '../../../features/notifications/notifications_models.dart';
import '../interfaces/communication_repository.dart';
import '../repository_query.dart';

class MockCommunicationRepository implements CommunicationRepository {
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
    return const [
      CommunicationTemplate(
        id: 'tpl-1',
        code: 'fee_reminder_push',
        channel: 'push',
        subjectTemplate: 'Fee reminder — {{term}}',
        bodyTemplate: '₹{{amount}} due by {{due_date}}.',
        variables: ['term', 'amount', 'due_date'],
      ),
    ];
  }

  @override
  Future<BroadcastResult> sendBroadcast({
    required RepositoryQuery query,
    required BroadcastRequest request,
  }) async {
    return const BroadcastResult(
      broadcastId: 'broadcast-mock-1',
      recipientCount: 42,
      status: 'sent',
    );
  }
}
