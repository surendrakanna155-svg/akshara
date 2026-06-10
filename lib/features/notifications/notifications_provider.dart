import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_config.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import 'notifications_models.dart';

/// Active inbox filter for [NotificationsScreen].
final notificationFilterProvider = StateProvider<NotificationFilter>(
  (ref) => NotificationFilter.all,
);

/// Unread badge count for parent AppBar bells.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider);
  return items.where((n) => !n.isRead && !n.isArchived).length;
});

/// Notification inbox — loads from Communication Hub when API is enabled.
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    Future.microtask(refresh);
    return List<AppNotification>.from(_fallbackInbox);
  }

  bool get _useApi => ref.read(communicationApiEnabledProvider);

  Future<void> refresh() async {
    if (!_useApi) {
      state = List<AppNotification>.from(_fallbackInbox);
      return;
    }
    try {
      final items = await ref.read(communicationRepositoryProvider).getNotifications(
            query: ref.read(repositoryQueryProvider),
          );
      state = items.isEmpty ? List<AppNotification>.from(_fallbackInbox) : items;
    } catch (_) {
      state = List<AppNotification>.from(_fallbackInbox);
    }
  }

  Future<void> markRead(String id) async {
    if (_useApi) {
      try {
        await ref.read(communicationRepositoryProvider).markNotificationRead(
              query: ref.read(repositoryQueryProvider),
              notificationId: id,
            );
      } catch (_) {
        // Keep optimistic local update on API failure.
      }
    }
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
  }

  Future<void> markAllRead() async {
    if (_useApi) {
      try {
        await ref.read(communicationRepositoryProvider).markAllNotificationsRead(
              query: ref.read(repositoryQueryProvider),
            );
      } catch (_) {
        // Keep optimistic local update on API failure.
      }
    }
    state = [for (final item in state) item.copyWith(isRead: true)];
  }

  void archive(String id) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(isArchived: true) else item,
    ];
  }

  List<AppNotification> filtered(NotificationFilter filter) {
    final visible = state.where((n) => !n.isArchived).toList();
    return switch (filter) {
      NotificationFilter.all => visible,
      NotificationFilter.unread => visible.where((n) => !n.isRead).toList(),
      NotificationFilter.fees =>
        visible.where((n) => n.category == NotificationCategory.fee).toList(),
      NotificationFilter.attendance => visible
          .where((n) => n.category == NotificationCategory.attendance)
          .toList(),
      NotificationFilter.academic => visible
          .where((n) => n.category == NotificationCategory.academic)
          .toList(),
    };
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

final _fallbackInbox = <AppNotification>[
  AppNotification(
    id: 'nt-001',
    title: 'Fee reminder — Term 2',
    preview: '₹4,200 due by 15 Jun. Pay online to avoid late fee.',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    category: NotificationCategory.fee,
    isUrgent: true,
    childContext: 'Ravi · 8-A',
  ),
  AppNotification(
    id: 'nt-002',
    title: 'Attendance marked — Present',
    preview: 'Ravi was marked present for all sessions today.',
    timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    category: NotificationCategory.attendance,
    childContext: 'Ravi · 8-A',
  ),
  AppNotification(
    id: 'nt-003',
    title: 'Science project submission',
    preview: 'Submit volcano model by Monday, 9 Jun.',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    category: NotificationCategory.academic,
    isRead: true,
    childContext: 'Ravi · 8-A',
  ),
  AppNotification(
    id: 'nt-004',
    title: 'School holiday — Eid',
    preview: 'School closed on 7 Jun. Regular classes resume 8 Jun.',
    timestamp: DateTime.now().subtract(const Duration(days: 2)),
    category: NotificationCategory.announcement,
    isRead: true,
  ),
  AppNotification(
    id: 'nt-005',
    title: 'Bus route delay',
    preview: 'Route 12 running 15 min late due to traffic near Main Rd.',
    timestamp: DateTime.now().subtract(const Duration(days: 3)),
    category: NotificationCategory.transport,
    isRead: true,
  ),
];
