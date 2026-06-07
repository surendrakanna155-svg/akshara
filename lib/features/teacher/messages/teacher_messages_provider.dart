import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
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

bool sendComposedMessage(WidgetRef ref) {
  final draft = ref.read(teacherComposeDraftProvider);
  if (!draft.isValid) return false;
  ref.read(teacherComposeDraftProvider.notifier).state = const ComposeDraft();
  ref.read(teacherMessageMailboxProvider.notifier).state = MessageMailbox.sent;
  return true;
}
