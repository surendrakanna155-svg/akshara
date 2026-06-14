import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../teacher/messages/message_models.dart';

final parentMessagesLoadingProvider = StateProvider<bool>((ref) => false);
final parentMessagesErrorProvider = StateProvider<bool>((ref) => false);
final parentMessagesEmptyProvider = StateProvider<bool>((ref) => false);
final parentComposeDraftProvider = StateProvider<ComposeDraft>(
  (ref) => const ComposeDraft(),
);

final parentMessageThreadsFutureProvider = FutureProvider<List<MessageThread>>((
  ref,
) async {
  return ref.read(parentRepositoryProvider).getMessageThreads(
        query: ref.watch(repositoryQueryProvider),
      );
});

final parentMessageThreadsProvider = Provider<List<MessageThread>>((ref) {
  if (ref.watch(parentMessagesEmptyProvider)) return const [];
  final items = watchRepositoryFuture(
    ref,
    ref.watch(parentMessageThreadsFutureProvider),
    manualLoading: ref.watch(parentMessagesLoadingProvider),
    manualError: ref.watch(parentMessagesErrorProvider),
    manualEmpty: ref.watch(parentMessagesEmptyProvider),
  );
  return items ?? ref.watch(parentMessageThreadsFutureProvider).value ?? const [];
});

final parentMessageThreadProvider = Provider.family<MessageThread?, String>(
  (ref, threadId) {
    for (final thread in ref.watch(parentMessageThreadsProvider)) {
      if (thread.id == threadId) return thread;
    }
    return null;
  },
);
