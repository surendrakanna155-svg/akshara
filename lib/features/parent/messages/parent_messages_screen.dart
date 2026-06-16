import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../teacher/messages/message_models.dart';
import '../messages/parent_messages_provider.dart';
import '../communication/parent_communication_inbox_provider.dart';

class ParentMessagesScreen extends ConsumerWidget {
  const ParentMessagesScreen({
    super.key,
    this.onThreadTap,
    this.onCommunicationTap,
    this.onNotificationsTap,
  });

  final void Function(MessageThread thread)? onThreadTap;
  final void Function(String communicationId)? onCommunicationTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(parentMessagesLoadingProvider);
    final hasError = ref.watch(parentMessagesErrorProvider);
    final threads = ref.watch(parentMessageThreadsProvider);
    final inbox = ref.watch(parentCommunicationInboxProvider);
    final inboxAsync = ref.watch(parentCommunicationInboxFutureProvider);

    return Scaffold(
      appBar: AksharaAppBar(
        titleText: 'Communication',
        subtitle: 'Inbox',
        onNotificationsTap: onNotificationsTap,
      ),
      body: loading || inboxAsync.isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load parent messages.',
                  onRetry: () {
                    ref.read(parentMessagesErrorProvider.notifier).state = false;
                    ref.invalidate(parentCommunicationInboxFutureProvider);
                  },
                )
              : inbox.isEmpty && threads.isEmpty
                  ? const AksharaEmptyState(
                      message: 'No messages from school yet.',
                      icon: Icons.inbox_outlined,
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AksharaSpacing.s4),
                      children: [
                        if (inbox.isNotEmpty) ...[
                          const AksharaSectionHeader(title: 'School messages'),
                          const SizedBox(height: AksharaSpacing.s2),
                          for (final item in inbox) ...[
                            ListTile(
                              tileColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                              title: Text(item.senderName),
                              subtitle: Text(
                                item.displayBody,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (item.isUnread)
                                    const Badge(label: Text('New'))
                                  else
                                    Text(
                                      item.deliveryStatusLabel,
                                      style:
                                          Theme.of(context).textTheme.labelSmall,
                                    ),
                                  Text(
                                    item.sentAtLabel,
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                              onTap: onCommunicationTap == null
                                  ? null
                                  : () => onCommunicationTap!(item.id),
                            ),
                            const SizedBox(height: AksharaSpacing.s2),
                          ],
                        ],
                        if (threads.isNotEmpty) ...[
                          const AksharaSectionHeader(title: 'Conversations'),
                          const SizedBox(height: AksharaSpacing.s2),
                          for (final thread in threads)
                            ListTile(
                              tileColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                              title: Text(thread.studentName),
                              subtitle: Text(
                                thread.preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: thread.unreadCount > 0
                                  ? Badge(label: Text('${thread.unreadCount}'))
                                  : Text(thread.timeLabel),
                              onTap: onThreadTap == null
                                  ? null
                                  : () => onThreadTap!(thread),
                            ),
                        ],
                      ],
                    ),
    );
  }
}
