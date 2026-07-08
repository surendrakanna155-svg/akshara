import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/async/erp_async_state.dart';
import 'parent_meeting_models.dart';
import 'parent_meetings_mutations_provider.dart';
import 'parent_meetings_providers.dart';
import '../../theme/spacing.dart';

class ParentMeetingDetailScreen extends ConsumerStatefulWidget {
  const ParentMeetingDetailScreen({
    super.key,
    required this.meetingId,
  });

  final String meetingId;

  @override
  ConsumerState<ParentMeetingDetailScreen> createState() =>
      _ParentMeetingDetailScreenState();
}

class _ParentMeetingDetailScreenState
    extends ConsumerState<ParentMeetingDetailScreen> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meetingsState = ref.watch(parentMeetingsFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Meeting Details')),
      body: ErpAsyncBody(
        state: resolveErpAsync(meetingsState, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No parent meetings yet',
        onRetry: () => ref.invalidate(parentMeetingsFutureProvider),
        builder: (meetings) {
          ParentMeetingRecord? meeting;
          for (final item in meetings) {
            if (item.id == widget.meetingId) {
              meeting = item;
              break;
            }
          }
          if (meeting == null) {
            return const Center(child: Text('Meeting not found'));
          }
          _notesController.text = meeting.notes;
          return ListView(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            children: [
              Text(
                '${meeting.studentName} with ${meeting.parentName}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                key: QaTestKeys.parentMeetingsNotesField,
                controller: _notesController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Meeting Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: QaTestKeys.parentMeetingsSaveNotesButton,
                    onPressed: () => _saveNotes(meeting!),
                    child: const Text('Save Notes'),
                  ),
                  OutlinedButton.icon(
                    key: QaTestKeys.parentMeetingsGenerateSummaryButton,
                    onPressed: () => _generateSummary(meeting!),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate AI Summary'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        context.push(RouteNames.communicationBroadcastAdmin),
                    child: const Text('Open Communication Hub'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'AI Summary',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AksharaSpacing.s3),
                  child: Text(
                    meeting.aiSummary?.trim().isNotEmpty == true
                        ? meeting.aiSummary!
                        : 'Generate a summary from meeting notes.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Action Items',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...meeting.actionItems.map(
                (item) => CheckboxListTile(
                  key: QaTestKeys.parentMeetingActionToggle(item.id),
                  title: Text(item.title),
                  subtitle: item.dueDate == null
                      ? null
                      : Text('Due: ${item.dueDate!.toLocal()}'),
                  value: item.completed,
                  onChanged: (value) =>
                      _completeAction(meeting!, item, value ?? false),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Follow-ups',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    key: QaTestKeys.parentMeetingsScheduleFollowUpButton,
                    onPressed: () => _scheduleFollowUp(meeting!),
                    child: const Text('Schedule Follow-up'),
                  ),
                ],
              ),
              ...meeting.followUps.map(
                (item) => ListTile(
                  title: Text('${item.channel} | ${item.status}'),
                  subtitle: Text(
                      '${item.scheduledAt.toLocal()}\n${item.notes ?? ''}'),
                  isThreeLine: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveNotes(ParentMeetingRecord meeting) async {
    await ref.read(parentMeetingsMutationsProvider.notifier).saveNotes(
          meetingId: meeting.id,
          notes: _notesController.text.trim(),
        );
  }

  Future<void> _generateSummary(ParentMeetingRecord meeting) async {
    await ref.read(parentMeetingsMutationsProvider.notifier).generateSummary(
          meeting: meeting.copyWith(notes: _notesController.text.trim()),
        );
  }

  Future<void> _completeAction(
    ParentMeetingRecord meeting,
    MeetingActionItem item,
    bool completed,
  ) async {
    await ref.read(parentMeetingsMutationsProvider.notifier).completeAction(
          meetingId: meeting.id,
          actionItemId: item.id,
          completed: completed,
        );
  }

  Future<void> _scheduleFollowUp(ParentMeetingRecord meeting) async {
    await ref.read(parentMeetingsMutationsProvider.notifier).scheduleFollowUp(
          meetingId: meeting.id,
          scheduledAt: DateTime.now().add(const Duration(days: 7)),
          channel: 'call',
          notes: 'Weekly academic follow-up with parent',
          notifyParent: true,
        );
  }
}
