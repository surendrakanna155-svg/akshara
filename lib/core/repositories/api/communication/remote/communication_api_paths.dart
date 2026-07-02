abstract final class CommunicationApiPaths {
  static const String templates = '/communications/templates';
  static const String broadcasts = '/communications/broadcasts';
  static const String broadcastHistory = '/communications/broadcasts/history';
  static const String audienceSegments = '/communications/audience-segments';
  static const String parentNotifications = '/parent/notifications';
  static const String parentMarkRead = '/parent/notifications/mark-read';
  static const String parentMarkAllRead = '/parent/notifications/mark-all-read';
  static const String parentDeviceRegister = '/parent/device-tokens/register';
  static const String parentDeviceUnregister =
      '/parent/device-tokens/unregister';
  static const String studentNotifications = '/student/notifications';
  static const String processQueue =
      '/communications/notifications/process-queue';

  static String template(String templateId) => '$templates/$templateId';

  /// COM-1: GET per-broadcast delivery & read report.
  static String broadcastReport(String broadcastId) =>
      '$broadcasts/$broadcastId/report';

  /// COM-3: POST re-enqueue a broadcast to its unread recipients.
  static String broadcastResend(String broadcastId) =>
      '$broadcasts/$broadcastId/resend';

  /// COM-2: DELETE a single saved audience segment.
  static String audienceSegment(String id) => '$audienceSegments/$id';

  /// COM-D1: POST acknowledge one of the caller's own deliveries.
  static String notificationAcknowledge(String deliveryId) =>
      '/communications/notifications/$deliveryId/acknowledge';
}
