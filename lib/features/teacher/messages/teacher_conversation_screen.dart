import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'message_models.dart';
import 'teacher_messages_provider.dart';

/// TA-06 conversation thread view.
class TeacherConversationScreen extends ConsumerWidget {
  const TeacherConversationScreen({
    super.key,
    required this.threadId,
    this.onNotificationsTap,
  });

  final String threadId;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = ref.watch(teacherMessageThreadProvider(threadId));
    final isLoading = ref.watch(teacherMessagesLoadingProvider);
    final hasError = ref.watch(teacherMessagesErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: thread?.parentName ?? 'Conversation',
        subtitle: thread?.studentName,
        unreadNotifications: 1,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load conversation.',
                  onRetry: () => ref
                      .read(teacherMessagesErrorProvider.notifier)
                      .state = false,
                )
              : thread == null
                  ? const AksharaEmptyState(
                      message: 'Conversation not found.',
                      icon: Icons.forum_outlined,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AksharaSpacing.s4),
                      itemCount: thread.messages.length,
                      itemBuilder: (context, index) {
                        final msg = thread.messages[index];
                        return _Bubble(message: msg);
                      },
                    ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final MessageItem message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final align =
        message.isTeacher ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = message.isTeacher
        ? colors.primaryContainer
        : colors.surfaceContainerHigh;

    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Semantics(
            label: '${message.senderLabel}: ${message.body}',
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AksharaSpacing.s3),
              ),
              child: Text(
                message.body,
                style: text.bodyMedium.copyWith(color: colors.onSurface),
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s1),
          Text(
            message.timeLabel,
            style: text.labelSmall.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
