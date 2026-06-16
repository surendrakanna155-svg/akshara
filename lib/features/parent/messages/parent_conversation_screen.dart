import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'parent_messages_provider.dart';
import '../parent_requests.dart';
import 'package:flutter/services.dart';

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
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              itemCount: thread.messages.length,
              itemBuilder: (context, index) {
                final msg = thread.messages[index];
                return Align(
                  alignment: msg.isTeacher
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AksharaSpacing.s2),
                    padding: const EdgeInsets.all(AksharaSpacing.s3),
                    decoration: BoxDecoration(
                      color: msg.isTeacher
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AksharaSpacing.s2),
                    ),
                    child: Text(msg.body),
                  ),
                );
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
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border(
              top: BorderSide(color: Theme.of(context).colorScheme.outline),
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
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(2000),
                    ],
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
                            await ref.read(parentRepositoryProvider).sendMessage(
                                  query: ref.read(repositoryQueryProvider),
                                  request: ParentMessageSendRequest(
                                    recipient: widget.recipient,
                                    subject: widget.subject,
                                    body: _controller.text.trim(),
                                    threadId: widget.threadId,
                                  ),
                                );
                            _controller.clear();
                            if (!context.mounted) return;
                            ref.invalidate(parentMessageThreadsFutureProvider);
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
