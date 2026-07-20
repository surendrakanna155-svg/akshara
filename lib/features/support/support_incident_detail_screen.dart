import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'domain/support_models.dart';
import 'support_providers.dart';
import 'support_ui.dart';

/// ASIP Phase 1 screen (c) — one reported issue: header + status, the
/// auto-collected timeline (lite), attachments, and the conversation with
/// Akshara Support, with a reply box. Evidence/AI diagnosis are support-only and
/// are never surfaced here (they are not returned to a reporter payload).
class SupportIncidentDetailScreen extends ConsumerStatefulWidget {
  const SupportIncidentDetailScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  ConsumerState<SupportIncidentDetailScreen> createState() =>
      _SupportIncidentDetailScreenState();
}

class _SupportIncidentDetailScreenState
    extends ConsumerState<SupportIncidentDetailScreen> {
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final body = _replyController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportActionsProvider).reply(
            incidentId: widget.incidentId,
            body: body,
          );
      _replyController.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send your reply. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(supportIncidentDetailProvider(widget.incidentId));

    return Scaffold(
      key: QaTestKeys.supportIncidentDetailScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: const AksharaAppBar(
        titleText: 'Reported issue',
        subtitle: 'Your conversation with Akshara Support',
        trailingPadding: true,
      ),
      body: async.when(
        loading: () => const AksharaLoadingState(),
        error: (_, __) => AksharaErrorState(
          message: 'Unable to load this issue.',
          onRetry: () =>
              ref.invalidate(supportIncidentDetailProvider(widget.incidentId)),
        ),
        data: (detail) => _DetailBody(
          detail: detail,
          replyController: _replyController,
          sending: _sending,
          onSend: _sendReply,
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.replyController,
    required this.sending,
    required this.onSend,
  });

  final SupportIncidentDetail detail;
  final TextEditingController replyController;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final messages = detail.visibleMessages;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AksharaSpacing.mobileMargin,
              AksharaSpacing.s4,
              AksharaSpacing.mobileMargin,
              AksharaSpacing.s8,
            ),
            children: [
              _Header(incident: detail.incident),
              if (detail.attachments.isNotEmpty) ...[
                const SizedBox(height: AksharaSpacing.s4),
                _AttachmentsStrip(attachments: detail.attachments),
              ],
              const SizedBox(height: AksharaSpacing.s5),
              const _SectionLabel(label: 'Progress'),
              const SizedBox(height: AksharaSpacing.s2),
              _Timeline(events: detail.events),
              const SizedBox(height: AksharaSpacing.s5),
              const _SectionLabel(label: 'Conversation'),
              const SizedBox(height: AksharaSpacing.s2),
              if (messages.isEmpty)
                const _MutedNote(
                  text: 'No messages yet. Add a note below if you have more '
                      'detail — Akshara Support will reply here.',
                )
              else
                for (final m in messages) ...[
                  _MessageBubble(message: m),
                  const SizedBox(height: AksharaSpacing.s2),
                ],
            ],
          ),
        ),
        _ReplyBar(
          controller: replyController,
          sending: sending,
          onSend: onSend,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.incident});

  final SupportIncident incident;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(AksharaSpacing.s3),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    incident.title,
                    style: text.titleMedium.copyWith(color: colors.onSurface),
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s2),
                AksharaStatusChip(
                  label: incident.status.label,
                  tone: supportStatusTone(incident.status),
                ),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              incident.description,
              style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  incident.publicRef,
                  style: text.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '·  ${formatSupportCategory(incident.category)}',
                  style: text.labelSmall.copyWith(color: colors.onSurfaceVariant),
                ),
                Text(
                  '·  Reported ${supportRelativeTime(incident.createdAt)}',
                  style: text.labelSmall.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            if (incident.status == SupportStatus.resolved &&
                (incident.resolutionSummary ?? '').isNotEmpty) ...[
              const SizedBox(height: AksharaSpacing.s3),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AksharaSpacing.s3),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AksharaSpacing.s2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resolution',
                      style: text.labelMedium.copyWith(color: colors.onSurface),
                    ),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      incident.resolutionSummary!,
                      style: text.bodySmall
                          .copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttachmentsStrip extends StatelessWidget {
  const _AttachmentsStrip({required this.attachments});

  final List<SupportAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: AksharaSpacing.s2),
        itemBuilder: (context, index) {
          final a = attachments[index];
          final hasImage = a.isImage && (a.downloadUrl ?? '').isNotEmpty;
          return Container(
            width: 84,
            height: 84,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AksharaSpacing.s2),
            ),
            child: hasImage
                ? Image.network(
                    a.downloadUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _AttachmentFallback(kind: a.kind),
                  )
                : _AttachmentFallback(kind: a.kind),
          );
        },
      ),
    );
  }
}

class _AttachmentFallback extends StatelessWidget {
  const _AttachmentFallback({required this.kind});

  final AttachmentKind kind;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      AttachmentKind.screenshot => Icons.image_outlined,
      AttachmentKind.screenRecording => Icons.videocam_outlined,
      AttachmentKind.logExport => Icons.description_outlined,
    };
    return Center(
      child: Icon(icon, color: context.colors.onSurfaceVariant),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<SupportIncidentEvent> events;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    if (events.isEmpty) {
      return const _MutedNote(text: 'No activity yet.');
    }
    return Column(
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  supportEventIcon(e.eventType),
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: AksharaSpacing.s2),
                Expanded(
                  child: Text(
                    supportEventLabel(e),
                    style: text.bodySmall.copyWith(color: colors.onSurface),
                  ),
                ),
                Text(
                  supportRelativeTime(e.createdAt),
                  style:
                      text.labelSmall.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final mine = message.isFromReporter;
    final bg = mine ? colors.primaryContainer : colors.surfaceContainer;
    final fg = mine ? colors.onPrimaryContainer : colors.onSurface;
    final who = switch (message.senderKind) {
      SupportSenderKind.reporter => 'You',
      SupportSenderKind.support => 'Akshara Support',
      SupportSenderKind.system => 'System',
    };
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.all(AksharaSpacing.s3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                who,
                style: text.labelSmall
                    .copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(message.body, style: text.bodyMedium.copyWith(color: fg)),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                supportRelativeTime(message.createdAt),
                style: text.labelSmall
                    .copyWith(color: fg.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceContainer,
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: QaTestKeys.supportReplyField,
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Add a message…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s2),
              IconButton.filled(
                key: QaTestKeys.supportReplySendButton,
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.aksharaText.titleSmall
          .copyWith(color: context.colors.onSurface),
    );
  }
}

class _MutedNote extends StatelessWidget {
  const _MutedNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.aksharaText.bodySmall
          .copyWith(color: context.colors.onSurfaceVariant),
    );
  }
}
