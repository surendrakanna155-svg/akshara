import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/communication/parent_communication_models.dart';
import '../../../core/communication/teacher_parent_templates.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'teacher_parent_communication_provider.dart';
import 'teacher_teaching_context_provider.dart';

/// Teacher → parent communication workflow (templates, translate, multi-channel).
class TeacherParentCommunicationScreen extends ConsumerWidget {
  const TeacherParentCommunicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(teacherCommunicationStudentsProvider);
    final selectedId = ref.watch(teacherCommunicationSelectedStudentProvider);
    final reason = ref.watch(teacherCommunicationReasonProvider);
    final tone = ref.watch(teacherCommunicationToneProvider);
    final channels = ref.watch(teacherCommunicationChannelsProvider);
    final translation =
        ref.watch(teacherCommunicationTranslationPreviewProvider);
    final sendState = ref.watch(sendTeacherParentCommunicationProvider);
    final canSend = ref.watch(teacherCanSendParentCommunicationProvider);
    final teachingContext = ref.watch(resolvedTeacherTeachingContextProvider);
    final pendingConcerns =
        ref.watch(pendingSubjectConcernsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: canSend ? 'Parent communication' : 'Flag concern',
        subtitle: canSend
            ? 'Class teacher · ${teachingContext.classTeacherClassLabel ?? ''}'
            : '${teachingContext.primarySubject} teacher',
      ),
      // DS V2 P4 — premium persona canvas behind the communication workflow.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            if (!canSend)
              const AksharaWarningBanner(
                message:
                    'Subject teachers escalate concerns to the class teacher. Parents are contacted only after class teacher review.',
                actionLabel: '',
                compactMessage: true,
              ),
            if (!canSend) const SizedBox(height: AksharaSpacing.s3),
            if (canSend && pendingConcerns.isNotEmpty) ...[
              const AksharaSectionHeader(
                  title: 'Pending subject teacher flags'),
              for (final concern in pendingConcerns)
                Card(
                  child: ListTile(
                    title: Text('${concern.studentName} · ${concern.subject}'),
                    subtitle: Text(concern.observation),
                    trailing: FilledButton(
                      onPressed: () {
                        ref
                            .read(teacherCommunicationSelectedStudentProvider
                                .notifier)
                            .state = concern.sisStudentId;
                        ref
                            .read(teacherCommunicationReasonProvider.notifier)
                            .state = concern.category.suggestedReason;
                        ref
                            .read(teacherCommunicationSourceConcernProvider
                                .notifier)
                            .state = concern.id;
                      },
                      child: const Text('Review'),
                    ),
                  ),
                ),
              const SizedBox(height: AksharaSpacing.s3),
            ],
            const AksharaSectionHeader(title: '1. Select student'),
            const SizedBox(height: AksharaSpacing.s2),
            DropdownButtonFormField<String>(
              // Long "Name · Class" labels overflowed the field by a few px at
              // narrow widths; expand + ellipsis (matches the homework dropdown).
              isExpanded: true,
              initialValue: selectedId,
              decoration: const InputDecoration(
                labelText: 'Student',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final student in students)
                  DropdownMenuItem(
                    value: student.sisStudentId,
                    child: Text(
                      '${student.studentName} · ${student.classLabel}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => ref
                  .read(teacherCommunicationSelectedStudentProvider.notifier)
                  .state = value,
            ),
            const SizedBox(height: AksharaSpacing.s4),
            const AksharaSectionHeader(title: '2. Select reason'),
            const SizedBox(height: AksharaSpacing.s2),
            Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                for (final item in ParentCommunicationReason.values)
                  ChoiceChip(
                    label: Text(item.label),
                    selected: reason == item,
                    onSelected: (_) => ref
                        .read(teacherCommunicationReasonProvider.notifier)
                        .state = item,
                  ),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s4),
            const AksharaSectionHeader(title: '3. Template tone'),
            const SizedBox(height: AksharaSpacing.s2),
            _ToneSelector(reason: reason, selected: tone),
            const SizedBox(height: AksharaSpacing.s4),
            const AksharaSectionHeader(title: '4. Review & translate'),
            const SizedBox(height: AksharaSpacing.s2),
            AksharaSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('English', style: context.aksharaText.labelMedium),
                  Text(translation.original),
                  const Divider(),
                  Text(
                    translation.targetLanguage.displayName,
                    style: context.aksharaText.labelMedium,
                  ),
                  Text(translation.translated),
                ],
              ),
            ),
            const SizedBox(height: AksharaSpacing.s4),
            if (canSend) ...[
              const AksharaSectionHeader(title: '5. Delivery channels'),
              const SizedBox(height: AksharaSpacing.s2),
              CheckboxListTile(
                value: channels.contains(ParentCommunicationChannel.inApp),
                onChanged: (checked) => _toggleChannel(
                  ref,
                  ParentCommunicationChannel.inApp,
                  checked ?? false,
                ),
                title: const Text('In-App (default)'),
                subtitle: const Text('Parent notification center & inbox'),
              ),
              CheckboxListTile(
                value: channels.contains(ParentCommunicationChannel.push),
                onChanged: (checked) => _toggleChannel(
                  ref,
                  ParentCommunicationChannel.push,
                  checked ?? false,
                ),
                title: const Text('Push notification'),
              ),
              CheckboxListTile(
                value: channels.contains(ParentCommunicationChannel.whatsApp),
                onChanged: (checked) => _toggleChannel(
                  ref,
                  ParentCommunicationChannel.whatsApp,
                  checked ?? false,
                ),
                title: const Text('WhatsApp'),
                subtitle: const Text('Opens with parent number preloaded'),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              OutlinedButton.icon(
                onPressed: selectedId == null
                    ? null
                    : () => _sendCustomAi(context, ref),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Generate custom message (AI)'),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              FilledButton.icon(
                onPressed: selectedId == null ||
                        channels.isEmpty ||
                        sendState.isLoading
                    ? null
                    : () => _send(ref, context),
                icon: sendState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Send to parent'),
              ),
              if (selectedId != null) ...[
                const SizedBox(height: AksharaSpacing.s4),
                const AksharaSectionHeader(title: 'Delivery status'),
                const SizedBox(height: AksharaSpacing.s2),
                ..._timelineTiles(ref, selectedId),
              ],
            ] else ...[
              const AksharaSectionHeader(title: 'Subject observation'),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Observation for class teacher',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => ref
                    .read(_subjectObservationProvider.notifier)
                    .state = value,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              DropdownButtonFormField<SubjectConcernCategory>(
                decoration: const InputDecoration(
                  labelText: 'Concern type',
                  border: OutlineInputBorder(),
                ),
                initialValue: ref.watch(_subjectConcernCategoryProvider),
                items: [
                  for (final cat in SubjectConcernCategory.values)
                    DropdownMenuItem(value: cat, child: Text(cat.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(_subjectConcernCategoryProvider.notifier).state =
                        value;
                  }
                },
              ),
              const SizedBox(height: AksharaSpacing.s4),
              FilledButton.icon(
                onPressed: selectedId == null
                    ? null
                    : () => _flagConcern(ref, context),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Flag for class teacher'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _timelineTiles(WidgetRef ref, String selectedId) {
    // PRA-P0-17 (S0/T2-F): provider is now async (live endpoint); an empty list
    // while loading/on error preserves the existing empty-state behaviour.
    final timeline = ref
            .watch(studentCommunicationTimelineProvider(selectedId))
            .valueOrNull ??
        const [];
    if (timeline.isEmpty) {
      return [
        const Text('No messages sent to this parent yet.'),
      ];
    }
    return [
      for (final record in timeline)
        Card(
          child: ListTile(
            title: Text(record.reason.label),
            subtitle: Text(record.deliveryStatusLabel),
            trailing: Text(
              record.channelsLabel,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
    ];
  }

  void _toggleChannel(
    WidgetRef ref,
    ParentCommunicationChannel channel,
    bool enabled,
  ) {
    final current = Set<ParentCommunicationChannel>.from(
      ref.read(teacherCommunicationChannelsProvider),
    );
    if (enabled) {
      current.add(channel);
    } else {
      current.remove(channel);
    }
    ref.read(teacherCommunicationChannelsProvider.notifier).state = current;
  }

  Future<void> _send(WidgetRef ref, BuildContext context) async {
    final result = await sendTeacherParentCommunication(ref);
    if (!context.mounted || result == null) return;
    if (result.whatsAppLaunchUri != null) {
      final uri = Uri.parse(result.whatsAppLaunchUri!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sent to ${result.record.studentName} via ${result.record.channels.map((c) => c.label).join(', ')}',
        ),
      ),
    );
  }

  Future<void> _sendCustomAi(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom message (AI)'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Describe the message to generate…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate & send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await sendTeacherParentCommunication(
      ref,
      customMessage: controller.text,
      useAi: true,
    );
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom AI message sent.')),
    );
  }

  Future<void> _flagConcern(WidgetRef ref, BuildContext context) async {
    final studentId = ref.read(teacherCommunicationSelectedStudentProvider);
    if (studentId == null) return;
    final result = await flagSubjectTeacherConcern(
      ref,
      sisStudentId: studentId,
      category: ref.read(_subjectConcernCategoryProvider),
      observation: ref.read(_subjectObservationProvider),
    );
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Concern flagged for ${result.concern.studentName}. Class teacher will review.',
        ),
      ),
    );
  }
}

final _subjectObservationProvider = StateProvider<String>((ref) => '');
final _subjectConcernCategoryProvider = StateProvider<SubjectConcernCategory>(
  (ref) => SubjectConcernCategory.lowMarks,
);

class _ToneSelector extends ConsumerWidget {
  const _ToneSelector({required this.reason, required this.selected});

  final ParentCommunicationReason reason;
  final ParentCommunicationTone selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = switch (reason) {
      ParentCommunicationReason.attendanceLow => const [
          ParentCommunicationTone.polite,
          ParentCommunicationTone.concerned,
          ParentCommunicationTone.followUp,
        ],
      ParentCommunicationReason.marksLow => const [
          ParentCommunicationTone.encouragement,
          ParentCommunicationTone.parentSupport,
          ParentCommunicationTone.improvementPlan,
        ],
      ParentCommunicationReason.homeworkMissing => const [
          ParentCommunicationTone.gentleReminder,
          ParentCommunicationTone.repeatedOccurrence,
          ParentCommunicationTone.parentIntervention,
        ],
      ParentCommunicationReason.disciplineIssue => const [
          ParentCommunicationTone.informational,
          ParentCommunicationTone.discussionRequested,
          ParentCommunicationTone.meetingRequested,
        ],
      ParentCommunicationReason.feeReminder => const [
          ParentCommunicationTone.friendlyReminder,
          ParentCommunicationTone.dueSoon,
          ParentCommunicationTone.overdue,
        ],
      ParentCommunicationReason.appreciation => const [
          ParentCommunicationTone.goodPerformance,
          ParentCommunicationTone.improvedAttendance,
          ParentCommunicationTone.positiveBehavior,
        ],
      ParentCommunicationReason.ptmRequest => const [
          ParentCommunicationTone.informational,
          ParentCommunicationTone.meetingRequested,
        ],
      ParentCommunicationReason.generalProgress => const [
          ParentCommunicationTone.goodPerformance,
          ParentCommunicationTone.encouragement,
        ],
    };

    return Wrap(
      spacing: AksharaSpacing.s2,
      runSpacing: AksharaSpacing.s2,
      children: [
        for (final tone in tones)
          ChoiceChip(
            label: Text(tone.name),
            selected: selected == tone,
            onSelected: (_) => ref
                .read(teacherCommunicationToneProvider.notifier)
                .state = tone,
          ),
      ],
    );
  }
}
