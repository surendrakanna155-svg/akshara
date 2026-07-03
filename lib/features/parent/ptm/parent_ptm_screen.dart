import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../parent_meetings/parent_meeting_models.dart';
import '../parent_active_child_provider.dart';
import '../parent_mutations_provider.dart';
import 'parent_ptm_provider.dart';

/// Parent mobile PTM — upcoming meetings, RSVP, action items & follow-ups for
/// the active child (PAR-1 RSVP, PAR-6 action items + next-PTM hero).
class ParentPtmScreen extends ConsumerWidget {
  const ParentPtmScreen({
    super.key,
    this.onNotificationsTap,
  });

  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(parentActiveChildProvider);
    final meetingsAsync = ref.watch(parentChildMeetingsProvider);
    final nextMeeting = ref.watch(parentNextMeetingProvider);

    return Scaffold(
      key: QaTestKeys.parentPtmScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Parent-Teacher Meetings',
        subtitle: child?.name ?? 'Your child',
        showAi: false,
        onNotificationsTap: onNotificationsTap,
      ),
      body: meetingsAsync.when(
        loading: () => const AksharaLoadingState(),
        error: (error, _) =>
            AksharaErrorState.fromFailure(apiFailureMapper.fromException(error)),
        data: (meetings) {
          if (meetings.isEmpty) {
            return const AksharaEmptyState(
              message:
                  'No scheduled meetings. Check school notices for PTM dates.',
              icon: Icons.groups_outlined,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            children: [
              if (nextMeeting != null) ...[
                _NextPtmHero(meeting: nextMeeting),
                const SizedBox(height: AksharaSpacing.s4),
              ],
              for (final meeting in meetings) ...[
                _MeetingCard(key: ValueKey(meeting.id), meeting: meeting),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// PAR-6 — "next PTM" hero card highlighting the soonest upcoming meeting.
class _NextPtmHero extends StatelessWidget {
  const _NextPtmHero({required this.meeting});

  final ParentMeetingRecord meeting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return AksharaSurfaceCard(
      key: QaTestKeys.parentPtmNextHero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_outlined, color: colors.primary),
              const SizedBox(width: AksharaSpacing.s2),
              Text(
                'Your next meeting',
                style: text.labelLarge.copyWith(color: colors.primary),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            meeting.teacherName,
            style: text.titleMedium,
          ),
          const SizedBox(height: AksharaSpacing.s1),
          Text(
            _friendlyDateTime(meeting.meetingAt),
            style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _MeetingCard extends ConsumerStatefulWidget {
  const _MeetingCard({super.key, required this.meeting});

  final ParentMeetingRecord meeting;

  @override
  ConsumerState<_MeetingCard> createState() => _MeetingCardState();
}

class _MeetingCardState extends ConsumerState<_MeetingCard> {
  /// Optimistic local RSVP so the recorded response reflects immediately,
  /// independent of the list refetch (which also updates it).
  MeetingRsvp? _localRsvp;

  ParentMeetingRecord get meeting => widget.meeting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final rsvpState = ref.watch(rsvpParentMeetingProvider);
    final isSubmitting = rsvpState.isLoading;
    final effectiveMeeting =
        _localRsvp != null ? meeting.copyWith(rsvp: _localRsvp) : meeting;

    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meeting.teacherName, style: text.titleMedium),
          const SizedBox(height: AksharaSpacing.s1),
          Text(
            _friendlyDateTime(meeting.meetingAt),
            style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          if (meeting.aiSummary?.isNotEmpty == true) ...[
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              meeting.aiSummary!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          ],

          // PAR-1 — RSVP accept / decline (or the recorded response).
          const SizedBox(height: AksharaSpacing.s3),
          _RsvpRow(
            meeting: effectiveMeeting,
            isSubmitting: isSubmitting,
            onRespond: _submitRsvp,
          ),

          // PAR-6 — action items.
          if (meeting.actionItems.isNotEmpty) ...[
            const SizedBox(height: AksharaSpacing.s3),
            Text(
              'Action items',
              style: text.labelLarge.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: AksharaSpacing.s1),
            for (final item in meeting.actionItems)
              _ActionItemRow(item: item),
          ],

          // PAR-6 — follow-ups.
          if (meeting.followUps.isNotEmpty) ...[
            const SizedBox(height: AksharaSpacing.s3),
            Text(
              'Follow-ups',
              style: text.labelLarge.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: AksharaSpacing.s1),
            for (final followUp in meeting.followUps)
              Padding(
                padding: const EdgeInsets.only(bottom: AksharaSpacing.s1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.schedule_outlined,
                        size: 18, color: colors.onSurfaceVariant),
                    const SizedBox(width: AksharaSpacing.s2),
                    Expanded(
                      child: Text(
                        '${_friendlyDateTime(followUp.scheduledAt)} · '
                        '${followUp.channel} (${followUp.status})',
                        style: text.bodySmall
                            .copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitRsvp(MeetingRsvpResponse response) async {
    final messenger = ScaffoldMessenger.of(context);
    // Optimistic: reflect the response immediately; revert on failure.
    final previous = _localRsvp;
    setState(() => _localRsvp = MeetingRsvp(response: response));
    try {
      await ref.read(rsvpParentMeetingProvider.notifier).execute(
            meetingId: meeting.id,
            response: response,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('RSVP recorded: ${response.label}')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _localRsvp = previous);
      messenger.showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(error))),
      );
    }
  }
}

class _RsvpRow extends StatelessWidget {
  const _RsvpRow({
    required this.meeting,
    required this.isSubmitting,
    required this.onRespond,
  });

  final ParentMeetingRecord meeting;
  final bool isSubmitting;
  final ValueChanged<MeetingRsvpResponse> onRespond;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;
    final rsvp = meeting.rsvp;

    if (rsvp != null) {
      final accepted = rsvp.response == MeetingRsvpResponse.accepted;
      return Row(
        key: QaTestKeys.parentPtmRsvpStatus(meeting.id),
        children: [
          Icon(
            accepted ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 20,
            color: accepted ? ext.success : colors.error,
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: Text(
              'You ${accepted ? 'accepted' : 'declined'} this meeting',
              style: text.bodyMedium.copyWith(
                color: accepted ? ext.success : colors.error,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: QaTestKeys.parentPtmRsvpAcceptButton(meeting.id),
            onPressed: isSubmitting
                ? null
                : () => onRespond(MeetingRsvpResponse.accepted),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Accept'),
          ),
        ),
        const SizedBox(width: AksharaSpacing.s3),
        Expanded(
          child: OutlinedButton.icon(
            key: QaTestKeys.parentPtmRsvpDeclineButton(meeting.id),
            onPressed: isSubmitting
                ? null
                : () => onRespond(MeetingRsvpResponse.declined),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Decline'),
          ),
        ),
      ],
    );
  }
}

class _ActionItemRow extends StatelessWidget {
  const _ActionItemRow({required this.item});

  final MeetingActionItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;

    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.completed
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: 18,
            color: item.completed ? ext.success : colors.onSurfaceVariant,
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: Text(
              item.owner == null ? item.title : '${item.title} · ${item.owner}',
              style: text.bodySmall.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

String _friendlyDateTime(DateTime dt) {
  final local = dt.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  return '${local.day} ${months[local.month - 1]} ${local.year} · '
      '$hour:$minute $ampm';
}
