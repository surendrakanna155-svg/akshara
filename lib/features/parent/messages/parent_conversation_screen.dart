import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import 'parent_messages_provider.dart';

class ParentConversationScreen extends ConsumerWidget {
  const ParentConversationScreen({
    super.key,
    required this.threadId,
    this.onNotificationsTap,
  });

  final String threadId;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = ref.watch(parentMessageThreadProvider(threadId));
    if (thread == null) {
      return const Scaffold(
        body: AksharaEmptyState(
          message: 'Conversation not found.',
          icon: Icons.forum_outlined,
        ),
      );
    }
    return Scaffold(
      appBar: AksharaAppBar(
        titleText: thread.studentName,
        subtitle: thread.parentName,
        onNotificationsTap: onNotificationsTap,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        itemCount: thread.messages.length,
        itemBuilder: (context, index) {
          final msg = thread.messages[index];
          return Align(
            alignment: msg.isTeacher ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: AksharaSpacing.s2),
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              decoration: BoxDecoration(
                color: msg.isTeacher
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AksharaSpacing.s2),
              ),
              child: Text(msg.body),
            ),
          );
        },
      ),
    );
  }
}
