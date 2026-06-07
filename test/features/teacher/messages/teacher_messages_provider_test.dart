import 'package:akshara_erp/features/teacher/messages/message_models.dart';
import 'package:akshara_erp/features/teacher/messages/teacher_messages_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('teacherMessages providers', () {
    test('teacherMessageThreadsProvider exposes inbox threads', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final threads = container.read(teacherMessageThreadsProvider);

      expect(threads, hasLength(2));
      expect(threads.first.parentName, 'Suresh Kumar');
      expect(threads.first.messages, isNotEmpty);
    });

    test('teacherMessageThreadProvider resolves thread by id', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final thread = container.read(teacherMessageThreadProvider('thread_1'));

      expect(thread?.id, 'thread_1');
      expect(thread?.unreadCount, 1);
    });

    test('teacherMessageMailboxProvider switches mailbox tab', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(teacherMessageMailboxProvider.notifier).state =
          MessageMailbox.compose;
      expect(container.read(teacherMessageMailboxProvider),
          MessageMailbox.compose);
    });

    test('teacherComposeDraftProvider validates compose form', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(teacherComposeDraftProvider).isValid, isFalse);

      container.read(teacherComposeDraftProvider.notifier).state =
          const ComposeDraft(
        recipient: 'Suresh Kumar',
        subject: 'Homework update',
        body: 'Please review the attached worksheet.',
      );

      expect(container.read(teacherComposeDraftProvider).isValid, isTrue);
    });

    test('teacherMessagesEmptyProvider clears threads', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(teacherMessagesEmptyProvider.notifier).state = true;
      expect(container.read(teacherMessageThreadsProvider), isEmpty);
    });
  });
}
