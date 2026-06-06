import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_models.dart';

final teacherMessageMailboxProvider = StateProvider<MessageMailbox>(
  (ref) => MessageMailbox.inbox,
);

final teacherMessagesLoadingProvider = StateProvider<bool>((ref) => false);
final teacherMessagesErrorProvider = StateProvider<bool>((ref) => false);
final teacherMessagesEmptyProvider = StateProvider<bool>((ref) => false);
final teacherComposeDraftProvider = StateProvider<ComposeDraft>(
  (ref) => const ComposeDraft(),
);

final teacherMessageThreadsProvider = Provider<List<MessageThread>>((ref) {
  if (ref.watch(teacherMessagesEmptyProvider)) return const [];
  return _mockThreads();
});

final teacherMessageThreadProvider = Provider.family<MessageThread?, String>(
  (ref, threadId) {
    for (final thread in ref.watch(teacherMessageThreadsProvider)) {
      if (thread.id == threadId) return thread;
    }
    return null;
  },
);

List<MessageThread> _mockThreads() {
  return const [
    MessageThread(
      id: 'thread_1',
      parentName: 'Suresh Kumar',
      studentName: 'Ravi Kumar · 8-A',
      preview: 'Could you share the homework solution steps?',
      timeLabel: '10:24 AM',
      unreadCount: 1,
      messages: [
        MessageItem(
          id: 'm1',
          body: 'Could you share the homework solution steps for Q5?',
          senderLabel: 'Suresh Kumar',
          timeLabel: '10:24 AM',
          isTeacher: false,
        ),
        MessageItem(
          id: 'm2',
          body: 'I will upload worked examples by evening.',
          senderLabel: 'Priya Sharma',
          timeLabel: '10:40 AM',
          isTeacher: true,
        ),
      ],
    ),
    MessageThread(
      id: 'thread_2',
      parentName: 'Lakshmi Nair',
      studentName: 'Ananya Rao · 8-A',
      preview: 'Thank you for the PTM slot confirmation.',
      timeLabel: 'Yesterday',
      unreadCount: 0,
      messages: [
        MessageItem(
          id: 'm3',
          body: 'Thank you for the PTM slot confirmation.',
          senderLabel: 'Lakshmi Nair',
          timeLabel: 'Yesterday',
          isTeacher: false,
        ),
      ],
    ),
  ];
}

bool sendComposedMessage(WidgetRef ref) {
  final draft = ref.read(teacherComposeDraftProvider);
  if (!draft.isValid) return false;
  ref.read(teacherComposeDraftProvider.notifier).state = const ComposeDraft();
  ref.read(teacherMessageMailboxProvider.notifier).state = MessageMailbox.sent;
  return true;
}
