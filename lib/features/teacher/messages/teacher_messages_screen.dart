import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/layout/mobile_dashboard_layout.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../core/widgets/whatsapp_contact_button.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'message_models.dart';
import 'teacher_messages_provider.dart';
import '../communication/teacher_teaching_context_provider.dart';
import '../teacher_unread_provider.dart';
import '../../../theme/breakpoints.dart';

/// Teacher messages inbox — TA-06.
class TeacherMessagesScreen extends ConsumerWidget {
  const TeacherMessagesScreen({
    super.key,
    this.onNotificationsTap,
    this.onThreadTap,
  });

  final VoidCallback? onNotificationsTap;
  final void Function(MessageThread thread)? onThreadTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth =
      AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mailbox = ref.watch(teacherMessageMailboxProvider);
    final threads = ref.watch(teacherMessageThreadsProvider);
    final draft = ref.watch(teacherComposeDraftProvider);
    final isLoading = ref.watch(teacherMessagesLoadingProvider);
    final hasError = ref.watch(teacherMessagesErrorProvider);
    final teaching = ref.watch(resolvedTeacherTeachingContextProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Messages',
        subtitle: teaching.teacherName,
        unreadNotifications: ref.watch(teacherUnreadNotificationsProvider),
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load messages.',
                  onRetry: () => ref
                      .read(teacherMessagesErrorProvider.notifier)
                      .state = false,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= _tabletBreakpoint;
                    final pad = isTablet
                        ? AksharaSpacing.tabletMargin
                        : AksharaSpacing.mobileMargin;

                    return MobileDashboardLayout.boundedShellBody(
                      constraints: constraints,
                      maxContentWidth: isTablet ? _tabletMaxContentWidth : null,
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              pad,
                              AksharaSpacing.s4,
                              pad,
                              AksharaSpacing.s3,
                            ),
                            child: Semantics(
                              label: 'Mailbox selector',
                              child: SegmentedButton<MessageMailbox>(
                                segments: [
                                  for (final m in MessageMailbox.values)
                                    ButtonSegment(
                                      value: m,
                                      label: Text(m.label),
                                    ),
                                ],
                                selected: {mailbox},
                                showSelectedIcon: false,
                                onSelectionChanged: (v) => ref
                                    .read(
                                      teacherMessageMailboxProvider.notifier,
                                    )
                                    .state = v.first,
                              ),
                            ),
                          ),
                          Expanded(
                            child: switch (mailbox) {
                              MessageMailbox.compose => _ComposePane(
                                  draft: draft,
                                  pad: pad,
                                ),
                              MessageMailbox.inbox ||
                              MessageMailbox.sent =>
                                threads.isEmpty
                                    ? const AksharaEmptyState(
                                        message: 'No messages yet.',
                                        icon: Icons.forum_outlined,
                                      )
                                    : RefreshIndicator(
                                        onRefresh: () async => ref.invalidate(
                                            teacherMessageThreadsFutureProvider),
                                        child: ListView.separated(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: pad,
                                          ),
                                          itemCount: threads.length,
                                          separatorBuilder: (_, __) => Divider(
                                            color:
                                                context.colors.outlineVariant,
                                          ),
                                          itemBuilder: (context, index) {
                                            final thread = threads[index];
                                            return _ThreadRow(
                                              thread: thread,
                                              onTap: onThreadTap == null
                                                  ? null
                                                  : () => onThreadTap!(thread),
                                            );
                                          },
                                        ),
                                      ),
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread, this.onTap});

  final MessageThread thread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: onTap != null,
      label: '${thread.parentName}, ${thread.preview}',
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Text(thread.parentName[0]),
        ),
        title: Text(thread.parentName, style: text.titleSmall),
        subtitle: Text(
          '${thread.studentName}\n${thread.preview}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: thread.unreadCount > 0
            ? Badge(label: Text('${thread.unreadCount}'))
            : Text(
                thread.timeLabel,
                style: text.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _ComposePane extends ConsumerWidget {
  const _ComposePane({required this.draft, required this.pad});

  final ComposeDraft draft;
  final double pad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.fromLTRB(pad, AksharaSpacing.s0, pad, AksharaSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'To (parent phone)',
              hintText: '+91 98765 43211',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ref
                .read(teacherComposeDraftProvider.notifier)
                .state = draft.copyWith(recipient: v),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ref
                .read(teacherComposeDraftProvider.notifier)
                .state = draft.copyWith(subject: v),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          TextField(
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            onChanged: (v) => ref
                .read(teacherComposeDraftProvider.notifier)
                .state = draft.copyWith(body: v),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          WhatsAppContactButton(
            phone: draft.recipient.trim(),
            label: 'Open in WhatsApp',
            message: draft.body.trim().isEmpty
                ? 'Hello from Akshara School'
                : draft.body.trim(),
            unavailableMessage:
                'Enter parent phone number in To field (E.164 or 10-digit).',
          ),
          const SizedBox(height: AksharaSpacing.s3),
          FilledButton(
            onPressed: draft.isValid
                ? () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await sendComposedMessage(ref);
                    if (!context.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Message sent.'
                              : 'Could not send message. Please try again.',
                        ),
                      ),
                    );
                  }
                : null,
            child: const Text('Send message'),
          ),
        ],
      ),
    );
  }
}
