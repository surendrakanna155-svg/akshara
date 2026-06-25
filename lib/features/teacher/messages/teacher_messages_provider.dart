import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../teacher_mutations_provider.dart';
import '../teacher_requests.dart';
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

final teacherMessageThreadsFutureProvider = FutureProvider<List<MessageThread>>((ref) async {
  return ref.read(teacherRepositoryProvider).getMessageThreads(
        query: ref.watch(repositoryQueryProvider),
      );
});

final teacherMessageThreadsProvider = Provider<List<MessageThread>>((ref) {
  if (ref.watch(teacherMessagesEmptyProvider)) return const [];
  final items = watchRepositoryFuture(
    ref,
    ref.watch(teacherMessageThreadsFutureProvider),
    manualLoading: ref.watch(teacherMessagesLoadingProvider),
    manualError: ref.watch(teacherMessagesErrorProvider),
    manualEmpty: ref.watch(teacherMessagesEmptyProvider),
  );
  return items ?? ref.watch(teacherMessageThreadsFutureProvider).value ?? const [];
});

final teacherMessageThreadProvider = Provider.family<MessageThread?, String>(
  (ref, threadId) {
    for (final thread in ref.watch(teacherMessageThreadsProvider)) {
      if (thread.id == threadId) return thread;
    }
    return null;
  },
);

/// Sends the composed message through the real, audited send pipeline
/// (`sendTeacherMessageProvider`). `threadId` is omitted so the backend opens a
/// new thread. Returns true only when the send persisted (a thread came back);
/// the draft is cleared and the mailbox flips to Sent only on success.
Future<bool> sendComposedMessage(WidgetRef ref) async {
  final draft = ref.read(teacherComposeDraftProvider);
  if (!draft.isValid) return false;
  final thread =
      await ref.read(sendTeacherMessageProvider.notifier).execute(
            TeacherMessageSendRequest(
              recipient: draft.recipient,
              subject: draft.subject,
              body: draft.body,
            ),
          );
  if (thread == null) return false;
  ref.read(teacherComposeDraftProvider.notifier).state = const ComposeDraft();
  ref.read(teacherMessageMailboxProvider.notifier).state = MessageMailbox.sent;
  return true;
}
