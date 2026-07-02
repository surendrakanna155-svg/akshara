import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'messages/message_models.dart';
import 'messages/teacher_messages_provider.dart';

/// Real unread-notification count for the teacher persona app-bar badge.
///
/// Sourced from the teacher's message threads (`unreadCount` per thread) — the
/// only unread surface the teacher app currently owns. Replaces the hardcoded
/// `unreadNotifications: 1` placeholders: when there is nothing unread this
/// returns 0 (never a fabricated 1).
final teacherUnreadNotificationsProvider = Provider<int>((ref) {
  final threads = ref.watch(teacherMessageThreadsProvider);
  return threads.fold<int>(0, (sum, MessageThread t) => sum + t.unreadCount);
});
