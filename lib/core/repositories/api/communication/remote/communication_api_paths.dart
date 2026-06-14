abstract final class CommunicationApiPaths {
  static const String templates = '/communications/templates';
  static const String broadcasts = '/communications/broadcasts';
  static const String broadcastHistory = '/communications/broadcasts/history';
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
}
