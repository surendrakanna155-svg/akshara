import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import 'parent_meetings_mutations_provider.dart';
import 'parent_meetings_providers.dart';
import 'parent_meeting_detail_screen.dart';

class ParentMeetingsScreen extends ConsumerStatefulWidget {
  const ParentMeetingsScreen({super.key});

  @override
  ConsumerState<ParentMeetingsScreen> createState() =>
      _ParentMeetingsScreenState();
}

class _ParentMeetingsScreenState extends ConsumerState<ParentMeetingsScreen> {
  final _studentIdController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _teacherNameController = TextEditingController();

  @override
  void dispose() {
    _studentIdController.dispose();
    _studentNameController.dispose();
    _parentNameController.dispose();
    _teacherNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meetingsState = ref.watch(parentMeetingsFutureProvider);

    return Scaffold(
      key: QaTestKeys.parentMeetingsScreen,
      appBar: AppBar(title: const Text('Parent Meeting Summary')),
      floatingActionButton: FloatingActionButton.extended(
        key: QaTestKeys.parentMeetingsCreateButton,
        onPressed: _openCreateMeetingDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Meeting'),
      ),
      body: meetingsState.when(
        loading: () => const AksharaLoadingState(),
        error: (error, _) => AksharaErrorState(message: '$error'),
        data: (meetings) {
          if (meetings.isEmpty) {
            return const Center(child: Text('No parent meetings yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final meeting = meetings[index];
              return Card(
                child: ListTile(
                  key: QaTestKeys.parentMeetingTile(meeting.id),
                  title: Text('${meeting.studentName} - ${meeting.parentName}'),
                  subtitle: Text(
                    '${meeting.teacherName} | ${meeting.meetingAt.toLocal()}',
                  ),
                  trailing: Icon(
                    meeting.aiSummary?.isNotEmpty == true
                        ? Icons.auto_awesome
                        : Icons.chevron_right,
                  ),
                  onTap: () {
                    ref.read(selectedParentMeetingIdProvider.notifier).state =
                        meeting.id;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ParentMeetingDetailScreen(meetingId: meeting.id),
                      ),
                    );
                  },
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: meetings.length,
          );
        },
      ),
    );
  }

  Future<void> _openCreateMeetingDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Parent Meeting'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  key: QaTestKeys.parentMeetingsStudentIdField,
                  controller: _studentIdController,
                  decoration: const InputDecoration(labelText: 'Student ID'),
                ),
                TextField(
                  key: QaTestKeys.parentMeetingsStudentNameField,
                  controller: _studentNameController,
                  decoration: const InputDecoration(labelText: 'Student Name'),
                ),
                TextField(
                  key: QaTestKeys.parentMeetingsParentNameField,
                  controller: _parentNameController,
                  decoration: const InputDecoration(labelText: 'Parent Name'),
                ),
                TextField(
                  key: QaTestKeys.parentMeetingsTeacherNameField,
                  controller: _teacherNameController,
                  decoration: const InputDecoration(labelText: 'Teacher Name'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: QaTestKeys.parentMeetingsCreateSubmitButton,
              onPressed: () async {
                await ref
                    .read(parentMeetingsMutationsProvider.notifier)
                    .createMeeting(
                      studentId: _studentIdController.text.trim(),
                      studentName: _studentNameController.text.trim(),
                      parentName: _parentNameController.text.trim(),
                      teacherName: _teacherNameController.text.trim(),
                      meetingAt: DateTime.now(),
                    );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
