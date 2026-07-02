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
  final List<AudienceSegment> _segments = [
    const AudienceSegment(
      id: 'seg-1',
      name: 'Grade 8 parents',
      audienceType: 'class_parents',
      className: '8',
      sectionName: 'A',
    ),
  ];
  // COM-D1: remembers which broadcasts were authored requires-ack so the mock
  // report can surface a plausible `acknowledged` progression.
  final Map<String, bool> _requiresAck = {};
  var _segmentSeq = 1;

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
    final now = DateTime.now();
    // COM-4: a scheduled_at pins the broadcast as SCHEDULED rather than sent.
    final scheduled = request.scheduledAt != null &&
        request.scheduledAt!.trim().isNotEmpty;
    final status = scheduled ? 'scheduled' : 'sent';
    if (!scheduled) {
      // Surface an immediate announcement to the targeted audience's notices.
      SchoolBroadcastStore.instance.add(
        title: request.title,
        body: request.body,
        audience: request.audience,
      );
    }
    final result = BroadcastResult(
      broadcastId: 'broadcast-${now.millisecondsSinceEpoch}',
      recipientCount: 42,
      status: status,
    );
    _requiresAck[result.broadcastId] = request.requiresAck;
    _history.insert(
      0,
      BroadcastHistoryItem(
        id: result.broadcastId,
        title: request.title,
        audience: request.audience,
        status: result.status,
        recipientCount: result.recipientCount,
        sentAt: scheduled
            ? (DateTime.tryParse(request.scheduledAt!) ?? now)
            : now,
      ),
    );
    return result;
  }

  @override
  Future<BroadcastDeliveryReport> getBroadcastReport({
    required RepositoryQuery query,
    required String broadcastId,
  }) async {
    final item = _history.firstWhere(
      (b) => b.id == broadcastId,
      orElse: () => BroadcastHistoryItem(
        id: broadcastId,
        title: 'Broadcast',
        audience: 'all_parents',
        status: 'sent',
        recipientCount: 0,
        sentAt: DateTime.now(),
      ),
    );
    // Derive plausible numbers from the in-memory recipient count.
    final total = item.recipientCount;
    final failed = total >= 20 ? 2 : 0;
    final sent = total - failed;
    final read = (sent * 0.6).round();
    final unread = sent - read;
    final requiresAck = _requiresAck[broadcastId] ?? false;
    final acknowledged = requiresAck ? (read * 0.5).round() : 0;
    return BroadcastDeliveryReport(
      id: item.id,
      title: item.title,
      audience: item.audience,
      status: item.status,
      requiresAck: requiresAck,
      sentAt: item.sentAt,
      counts: BroadcastDeliveryCounts(
        total: total,
        sent: sent,
        failed: failed,
        pending: 0,
        read: read,
        unread: unread,
        acknowledged: acknowledged,
      ),
      unreadRecipients: [
        for (var i = 0; i < unread && i < 10; i++)
          UnreadRecipient(userId: 'user-$i', name: 'Recipient ${i + 1}'),
      ],
    );
  }

  @override
  Future<int> resendBroadcastToUnread({
    required RepositoryQuery query,
    required String broadcastId,
  }) async {
    final report = await getBroadcastReport(
      query: query,
      broadcastId: broadcastId,
    );
    return report.counts.unread;
  }

  @override
  Future<List<AudienceSegment>> listAudienceSegments({
    required RepositoryQuery query,
  }) async {
    return List<AudienceSegment>.from(_segments);
  }

  @override
  Future<AudienceSegment> createAudienceSegment({
    required RepositoryQuery query,
    required String name,
    required String audienceType,
    String? className,
    String? sectionName,
  }) async {
    _segmentSeq += 1;
    final segment = AudienceSegment(
      id: 'seg-$_segmentSeq',
      name: name,
      audienceType: audienceType,
      className: className,
      sectionName: sectionName,
    );
    _segments.insert(0, segment);
    return segment;
  }

  @override
  Future<void> deleteAudienceSegment({
    required RepositoryQuery query,
    required String id,
  }) async {
    _segments.removeWhere((segment) => segment.id == id);
  }

  @override
  Future<void> acknowledgeNotification({
    required RepositoryQuery query,
    required String deliveryId,
  }) async {
    // No-op in the mock; the recipient UI updates optimistically.
  }
}
