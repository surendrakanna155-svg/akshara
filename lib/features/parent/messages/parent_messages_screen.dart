import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../teacher/messages/message_models.dart';
import 'parent_messages_provider.dart';

class ParentMessagesScreen extends ConsumerWidget {
  const ParentMessagesScreen({
    super.key,
    this.onThreadTap,
    this.onNotificationsTap,
  });

  final void Function(MessageThread thread)? onThreadTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(parentMessagesLoadingProvider);
    final hasError = ref.watch(parentMessagesErrorProvider);
    final threads = ref.watch(parentMessageThreadsProvider);
    return Scaffold(
      appBar: AksharaAppBar(
        titleText: 'Messages',
        subtitle: 'Parent communication',
        unreadNotifications: 1,
        onNotificationsTap: onNotificationsTap,
      ),
      body: loading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load parent messages.',
                  onRetry: () =>
                      ref.read(parentMessagesErrorProvider.notifier).state = false,
                )
              : threads.isEmpty
                  ? const AksharaEmptyState(
                      message: 'No conversation found.',
                      icon: Icons.chat_bubble_outline,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AksharaSpacing.s4),
                      itemCount: threads.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AksharaSpacing.s2),
                      itemBuilder: (context, index) {
                        final thread = threads[index];
                        return ListTile(
                          tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
                          title: Text(thread.studentName),
                          subtitle: Text(
                            thread.preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: thread.unreadCount > 0
                              ? Badge(label: Text('${thread.unreadCount}'))
                              : Text(thread.timeLabel),
                          onTap: onThreadTap == null ? null : () => onThreadTap!(thread),
                        );
                      },
                    ),
    );
  }
}
