import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'message_models.dart';
import '../teacher_requests.dart';
import '../teacher_mutations_provider.dart';
import '../teacher_unread_provider.dart';
import 'teacher_messages_provider.dart';
import '../../copilot/widgets/bottom_nav_ai_scope.dart';

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
        unreadNotifications: ref.watch(teacherUnreadNotificationsProvider),
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
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AksharaSpacing.s4),
                            itemCount: thread.messages.length,
                            itemBuilder: (context, index) {
                              final msg = thread.messages[index];
                              return _Bubble(message: msg);
                            },
                          ),
                        ),
                        _ReplyComposer(
                          threadId: thread.id,
                          recipient: thread.parentName,
                          subject: thread.studentName,
                        ),
                      ],
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

class _ReplyComposer extends ConsumerStatefulWidget {
  const _ReplyComposer({
    required this.threadId,
    required this.recipient,
    required this.subject,
  });

  final String threadId;
  final String recipient;
  final String subject;

  @override
  ConsumerState<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends ConsumerState<_ReplyComposer> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !_isSending && _controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AksharaSpacing.mobileMargin,
          right: AksharaSpacing.mobileMargin,
          // Clear the raised centre AI button's band so the composer's send
          // control is never painted over. Resolves to 0 when no button is drawn.
          bottom: MediaQuery.viewInsetsOf(context).bottom + BottomNavAiScope.reservedHeightOf(context),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHigh,
            border: Border(
              top: BorderSide(color: context.colors.outlineVariant),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s2,
              vertical: AksharaSpacing.s3,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Reply',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s2),
                FilledButton.icon(
                  onPressed: canSend
                      ? () async {
                          setState(() => _isSending = true);
                          try {
                            await ref
                                .read(sendTeacherMessageProvider.notifier)
                                .execute(
                                  TeacherMessageSendRequest(
                                    recipient: widget.recipient,
                                    subject: widget.subject,
                                    body: _controller.text.trim(),
                                    threadId: widget.threadId,
                                  ),
                                );
                            _controller.clear();
                            if (!context.mounted) return;
                            setState(() => _isSending = false);
                          } catch (_) {
                            if (!context.mounted) return;
                            setState(() => _isSending = false);
                          }
                        }
                      : null,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(_isSending ? 'Sending' : 'Send'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
