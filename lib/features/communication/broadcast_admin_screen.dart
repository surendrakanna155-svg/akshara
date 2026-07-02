import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure_mapper.dart';
import '../../core/reports/akshara_report_export_service.dart';
import '../../core/repositories/interfaces/communication_repository.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import 'communication_mutations_provider.dart';
import 'communication_providers.dart';

/// The 6 broadcast audiences the backend accepts, with friendly labels.
enum BroadcastAudience {
  allParents('all_parents', 'All parents'),
  allTeachers('all_teachers', 'All teachers'),
  allStudents('all_students', 'All students'),
  schoolWide('school_wide', 'Everyone (school-wide)'),
  classParents('class_parents', 'Class parents'),
  classStudents('class_students', 'Class students');

  const BroadcastAudience(this.value, this.label);

  final String value;
  final String label;

  /// The audience targets a specific class → class field is required.
  bool get isClassScoped =>
      this == BroadcastAudience.classParents ||
      this == BroadcastAudience.classStudents;

  static BroadcastAudience fromValue(String value) {
    return BroadcastAudience.values.firstWhere(
      (a) => a.value == value,
      orElse: () => BroadcastAudience.allParents,
    );
  }
}

class BroadcastAdminScreen extends ConsumerStatefulWidget {
  const BroadcastAdminScreen({super.key});

  @override
  ConsumerState<BroadcastAdminScreen> createState() =>
      _BroadcastAdminScreenState();
}

class _BroadcastAdminScreenState extends ConsumerState<BroadcastAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Compose state.
  BroadcastAudience _audience = BroadcastAudience.allParents;
  final _classController = TextEditingController();
  final _sectionController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _requiresAck = false;
  bool _scheduleForLater = false;
  DateTime? _scheduledAt;
  bool _showClassError = false;

  // Templates state.
  final _templateCodeController = TextEditingController();
  final _templateChannelController = TextEditingController(text: 'push');
  final _templateSubjectController = TextEditingController();
  final _templateBodyController = TextEditingController();
  final _templateVariablesController = TextEditingController();
  String? _editingTemplateId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _classController.dispose();
    _sectionController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _templateCodeController.dispose();
    _templateChannelController.dispose();
    _templateSubjectController.dispose();
    _templateBodyController.dispose();
    _templateVariablesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesState = ref.watch(communicationTemplatesFutureProvider);
    final historyState = ref.watch(communicationBroadcastHistoryFutureProvider);
    final segmentsState =
        ref.watch(communicationAudienceSegmentsFutureProvider);
    final sending = ref.watch(sendBroadcastProvider).isLoading;
    final savingTemplate = ref.watch(saveTemplateProvider).isLoading;

    return Scaffold(
      key: QaTestKeys.communicationBroadcastAdminScreen,
      appBar: AppBar(
        title: const Text('Broadcast Admin'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Compose'),
            Tab(text: 'Templates'),
            Tab(text: 'History'),
            Tab(text: 'Delivery'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ComposeTab(
            audience: _audience,
            onAudienceChanged: (value) => setState(() {
              _audience = value;
              _showClassError = false;
            }),
            classController: _classController,
            sectionController: _sectionController,
            titleController: _titleController,
            bodyController: _bodyController,
            requiresAck: _requiresAck,
            onRequiresAckChanged: (value) =>
                setState(() => _requiresAck = value),
            scheduleForLater: _scheduleForLater,
            onScheduleToggle: _onScheduleToggle,
            scheduledAt: _scheduledAt,
            onPickSchedule: _pickSchedule,
            showClassError: _showClassError,
            segmentsState: segmentsState,
            onSegmentSelected: _applySegment,
            onSaveSegment: _saveSegment,
            onDeleteSegment: _deleteSegment,
            templatesState: templatesState,
            onTemplateSelected: _applyTemplate,
            onSaveAsTemplate: _saveComposedAsTemplate,
            isLoading: sending,
            onSend: _sendBroadcast,
          ),
          _TemplatesTab(
            templatesState: templatesState,
            codeController: _templateCodeController,
            channelController: _templateChannelController,
            subjectController: _templateSubjectController,
            bodyController: _templateBodyController,
            variablesController: _templateVariablesController,
            editingTemplateId: _editingTemplateId,
            onEditTemplate: _startEditTemplate,
            onCancelEdit: _cancelEditTemplate,
            isLoading: savingTemplate,
            onSaveTemplate: _saveTemplate,
          ),
          _HistoryTab(
            historyState: historyState,
            onOpenReport: _openReport,
          ),
          _DeliveryTab(historyState: historyState),
        ],
      ),
    );
  }

  // --- Compose actions -------------------------------------------------------

  void _onScheduleToggle(bool value) {
    setState(() {
      _scheduleForLater = value;
      if (!value) _scheduledAt = null;
    });
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _applySegment(AudienceSegment segment) {
    setState(() {
      _audience = BroadcastAudience.fromValue(segment.audienceType);
      _classController.text = segment.className ?? '';
      _sectionController.text = segment.sectionName ?? '';
      _showClassError = false;
    });
  }

  void _applyTemplate(CommunicationTemplate template) {
    setState(() {
      if (template.subjectTemplate != null &&
          template.subjectTemplate!.isNotEmpty) {
        _titleController.text = template.subjectTemplate!;
      } else {
        _titleController.text = template.code;
      }
      _bodyController.text = template.bodyTemplate;
    });
  }

  Future<void> _sendBroadcast() async {
    final className = _classController.text.trim();
    if (_audience.isClassScoped && className.isEmpty) {
      setState(() => _showClassError = true);
      return;
    }
    if (_scheduleForLater && _scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a date and time to schedule.')),
      );
      return;
    }
    if (_scheduleForLater &&
        _scheduledAt != null &&
        _scheduledAt!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Heads up: the scheduled time is in the past.'),
        ),
      );
    }

    final request = BroadcastRequest(
      audience: _audience.value,
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      audienceClass: _audience.isClassScoped ? className : null,
      audienceSection: _audience.isClassScoped
          ? (_sectionController.text.trim().isEmpty
              ? null
              : _sectionController.text.trim())
          : null,
      requiresAck: _requiresAck,
      scheduledAt: _scheduleForLater ? _scheduledAt?.toIso8601String() : null,
    );
    await ref.read(sendBroadcastProvider.notifier).execute(request);
    if (!mounted) return;
    final result = ref.read(sendBroadcastProvider).valueOrNull;
    if (result != null) {
      final scheduled = result.status == 'scheduled';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scheduled
                ? 'Broadcast scheduled (${result.status})'
                : 'Broadcast sent to ${result.recipientCount} recipients (${result.status})',
          ),
        ),
      );
    }
  }

  Future<void> _saveSegment() async {
    final className = _classController.text.trim();
    if (_audience.isClassScoped && className.isEmpty) {
      setState(() => _showClassError = true);
      return;
    }
    final name = await _promptForName(
      title: 'Save audience segment',
      hint: 'Segment name',
    );
    if (name == null || name.isEmpty || !mounted) return;
    await ref.read(saveAudienceSegmentProvider.notifier).execute(
          name: name,
          audienceType: _audience.value,
          className: _audience.isClassScoped ? className : null,
          sectionName: _audience.isClassScoped
              ? (_sectionController.text.trim().isEmpty
                  ? null
                  : _sectionController.text.trim())
              : null,
        );
    if (!mounted) return;
    if (ref.read(saveAudienceSegmentProvider).valueOrNull != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Segment saved')),
      );
    }
  }

  Future<void> _deleteSegment(AudienceSegment segment) async {
    await ref.read(deleteAudienceSegmentProvider.notifier).execute(segment.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted "${segment.name}"')),
    );
  }

  Future<void> _saveComposedAsTemplate() async {
    final code = await _promptForName(
      title: 'Save as template',
      hint: 'Template code',
    );
    if (code == null || code.isEmpty || !mounted) return;
    await ref.read(saveTemplateProvider.notifier).execute(
          code: code,
          channel: 'push',
          subjectTemplate: _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
          bodyTemplate: _bodyController.text.trim(),
        );
    if (!mounted) return;
    if (ref.read(saveTemplateProvider).valueOrNull != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template saved')),
      );
    }
  }

  Future<String?> _promptForName({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  // --- Templates actions -----------------------------------------------------

  void _startEditTemplate(CommunicationTemplate template) {
    setState(() {
      _editingTemplateId = template.id;
      _templateCodeController.text = template.code;
      _templateChannelController.text = template.channel;
      _templateSubjectController.text = template.subjectTemplate ?? '';
      _templateBodyController.text = template.bodyTemplate;
      _templateVariablesController.text = template.variables.join(', ');
    });
    _tabController.animateTo(1);
  }

  void _cancelEditTemplate() {
    setState(() {
      _editingTemplateId = null;
      _templateCodeController.clear();
      _templateChannelController.text = 'push';
      _templateSubjectController.clear();
      _templateBodyController.clear();
      _templateVariablesController.clear();
    });
  }

  Future<void> _saveTemplate() async {
    final variables = _templateVariablesController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    await ref.read(saveTemplateProvider.notifier).execute(
          templateId: _editingTemplateId,
          code: _templateCodeController.text.trim(),
          channel: _templateChannelController.text.trim(),
          subjectTemplate: _templateSubjectController.text.trim().isEmpty
              ? null
              : _templateSubjectController.text.trim(),
          bodyTemplate: _templateBodyController.text.trim(),
          variables: variables,
        );
    if (!mounted) return;
    if (ref.read(saveTemplateProvider).valueOrNull != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingTemplateId == null ? 'Template saved' : 'Template updated',
          ),
        ),
      );
      _cancelEditTemplate();
    }
  }

  // --- History → report ------------------------------------------------------

  void _openReport(BroadcastHistoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BroadcastReportScreen(broadcastId: item.id),
      ),
    );
  }
}

class _ComposeTab extends StatelessWidget {
  const _ComposeTab({
    required this.audience,
    required this.onAudienceChanged,
    required this.classController,
    required this.sectionController,
    required this.titleController,
    required this.bodyController,
    required this.requiresAck,
    required this.onRequiresAckChanged,
    required this.scheduleForLater,
    required this.onScheduleToggle,
    required this.scheduledAt,
    required this.onPickSchedule,
    required this.showClassError,
    required this.segmentsState,
    required this.onSegmentSelected,
    required this.onSaveSegment,
    required this.onDeleteSegment,
    required this.templatesState,
    required this.onTemplateSelected,
    required this.onSaveAsTemplate,
    required this.isLoading,
    required this.onSend,
  });

  final BroadcastAudience audience;
  final ValueChanged<BroadcastAudience> onAudienceChanged;
  final TextEditingController classController;
  final TextEditingController sectionController;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final bool requiresAck;
  final ValueChanged<bool> onRequiresAckChanged;
  final bool scheduleForLater;
  final ValueChanged<bool> onScheduleToggle;
  final DateTime? scheduledAt;
  final Future<void> Function() onPickSchedule;
  final bool showClassError;
  final AsyncValue<List<AudienceSegment>> segmentsState;
  final ValueChanged<AudienceSegment> onSegmentSelected;
  final Future<void> Function() onSaveSegment;
  final Future<void> Function(AudienceSegment segment) onDeleteSegment;
  final AsyncValue<List<CommunicationTemplate>> templatesState;
  final ValueChanged<CommunicationTemplate> onTemplateSelected;
  final Future<void> Function() onSaveAsTemplate;
  final bool isLoading;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        // COM-2: reuse a saved segment.
        segmentsState.when(
          data: (segments) => segments.isEmpty
              ? const SizedBox.shrink()
              : _SegmentPicker(
                  segments: segments,
                  onSelected: onSegmentSelected,
                  onDelete: onDeleteSegment,
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        // COM-5: prefill from a template.
        templatesState.when(
          data: (templates) => templates.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<CommunicationTemplate>(
                    initialValue: null,
                    decoration:
                        const InputDecoration(labelText: 'Use template'),
                    items: [
                      for (final template in templates)
                        DropdownMenuItem(
                          value: template,
                          child: Text(template.code),
                        ),
                    ],
                    onChanged: (template) {
                      if (template != null) onTemplateSelected(template);
                    },
                  ),
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        // COM-4/COM-2: audience picker.
        DropdownButtonFormField<BroadcastAudience>(
          key: QaTestKeys.communicationAudiencePicker,
          initialValue: audience,
          decoration: const InputDecoration(labelText: 'Audience'),
          items: [
            for (final option in BroadcastAudience.values)
              DropdownMenuItem(value: option, child: Text(option.label)),
          ],
          onChanged: (value) {
            if (value != null) onAudienceChanged(value);
          },
        ),
        if (audience.isClassScoped) ...[
          const SizedBox(height: 12),
          TextField(
            key: QaTestKeys.communicationAudienceClassField,
            controller: classController,
            decoration: InputDecoration(
              labelText: 'Class',
              errorText: showClassError ? 'Class is required' : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: QaTestKeys.communicationAudienceSectionField,
            controller: sectionController,
            decoration: const InputDecoration(labelText: 'Section (optional)'),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: bodyController,
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Body'),
        ),
        const SizedBox(height: 8),
        // COM-D1: require acknowledgement.
        SwitchListTile(
          key: QaTestKeys.communicationRequiresAckSwitch,
          contentPadding: EdgeInsets.zero,
          title: const Text('Require acknowledgement'),
          subtitle: const Text('Recipients must confirm they have read this.'),
          value: requiresAck,
          onChanged: onRequiresAckChanged,
        ),
        // COM-4: schedule for later.
        SwitchListTile(
          key: QaTestKeys.communicationScheduleToggle,
          contentPadding: EdgeInsets.zero,
          title: const Text('Schedule for later'),
          value: scheduleForLater,
          onChanged: onScheduleToggle,
        ),
        if (scheduleForLater)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: Text(
              scheduledAt == null
                  ? 'Pick date & time'
                  : _formatSchedule(scheduledAt!),
            ),
            trailing: TextButton(
              onPressed: onPickSchedule,
              child: const Text('Choose'),
            ),
            onTap: onPickSchedule,
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onSaveSegment,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save as segment'),
            ),
            OutlinedButton.icon(
              onPressed: onSaveAsTemplate,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save as template'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: QaTestKeys.communicationBroadcastSendButton,
          onPressed: isLoading ? null : onSend,
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(scheduleForLater ? 'Schedule broadcast' : 'Send broadcast'),
        ),
      ],
    );
  }
}

class _SegmentPicker extends StatelessWidget {
  const _SegmentPicker({
    required this.segments,
    required this.onSelected,
    required this.onDelete,
  });

  final List<AudienceSegment> segments;
  final ValueChanged<AudienceSegment> onSelected;
  final Future<void> Function(AudienceSegment segment) onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<AudienceSegment>(
              key: QaTestKeys.communicationSegmentPicker,
              initialValue: null,
              decoration:
                  const InputDecoration(labelText: 'Use saved segment'),
              items: [
                for (final segment in segments)
                  DropdownMenuItem(
                    value: segment,
                    child: Text(segment.name),
                  ),
              ],
              onChanged: (segment) {
                if (segment != null) onSelected(segment);
              },
            ),
          ),
          PopupMenuButton<AudienceSegment>(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete a segment',
            onSelected: onDelete,
            itemBuilder: (context) => [
              for (final segment in segments)
                PopupMenuItem(
                  value: segment,
                  child: Text('Delete "${segment.name}"'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab({
    required this.templatesState,
    required this.codeController,
    required this.channelController,
    required this.subjectController,
    required this.bodyController,
    required this.variablesController,
    required this.editingTemplateId,
    required this.onEditTemplate,
    required this.onCancelEdit,
    required this.isLoading,
    required this.onSaveTemplate,
  });

  final AsyncValue<List<CommunicationTemplate>> templatesState;
  final TextEditingController codeController;
  final TextEditingController channelController;
  final TextEditingController subjectController;
  final TextEditingController bodyController;
  final TextEditingController variablesController;
  final String? editingTemplateId;
  final ValueChanged<CommunicationTemplate> onEditTemplate;
  final VoidCallback onCancelEdit;
  final bool isLoading;
  final Future<void> Function() onSaveTemplate;

  @override
  Widget build(BuildContext context) {
    final isEditing = editingTemplateId != null;
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        const Text('Existing templates',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        templatesState.when(
          data: (items) => Column(
            children: [
              for (final template in items)
                ListTile(
                  dense: true,
                  title: Text(template.code),
                  subtitle:
                      Text('${template.channel} · ${template.bodyTemplate}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit template',
                    onPressed: () => onEditTemplate(template),
                  ),
                ),
            ],
          ),
          loading: () => const AksharaLoadingState(),
          error: (error, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(error)),
        ),
        const Divider(),
        Text(
          isEditing ? 'Edit template' : 'New template',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: codeController,
          decoration: const InputDecoration(labelText: 'Template code'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: channelController,
          decoration: const InputDecoration(labelText: 'Channel'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: subjectController,
          decoration: const InputDecoration(labelText: 'Subject (optional)'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: bodyController,
          decoration: const InputDecoration(labelText: 'Body template'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: variablesController,
          decoration:
              const InputDecoration(labelText: 'Variables (comma separated)'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                key: QaTestKeys.communicationTemplateSaveButton,
                onPressed: isLoading ? null : onSaveTemplate,
                child: Text(
                  isLoading
                      ? 'Saving...'
                      : (isEditing ? 'Update template' : 'Save template'),
                ),
              ),
            ),
            if (isEditing) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onCancelEdit,
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.historyState,
    required this.onOpenReport,
  });

  final AsyncValue<List<BroadcastHistoryItem>> historyState;
  final ValueChanged<BroadcastHistoryItem> onOpenReport;

  @override
  Widget build(BuildContext context) {
    return historyState.when(
      data: (items) => ListView.builder(
        key: QaTestKeys.communicationBroadcastHistoryList,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            title: Text(item.title),
            subtitle: Text('${item.audience} · ${item.sentAt}'),
            trailing: Text(item.status),
            onTap: () => onOpenReport(item),
          );
        },
      ),
      loading: () => const AksharaLoadingState(),
      error: (error, _) =>
          AksharaErrorState.fromFailure(apiFailureMapper.fromException(error)),
    );
  }
}

class _DeliveryTab extends StatelessWidget {
  const _DeliveryTab({required this.historyState});

  final AsyncValue<List<BroadcastHistoryItem>> historyState;

  @override
  Widget build(BuildContext context) {
    return historyState.when(
      data: (items) {
        final total =
            items.fold<int>(0, (sum, item) => sum + item.recipientCount);
        final sent = items.where((item) => item.status == 'sent').length;
        return ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            ListTile(
                title: const Text('Total campaigns'),
                trailing: Text('${items.length}')),
            ListTile(
                title: const Text('Total recipients reached'),
                trailing: Text('$total')),
            ListTile(
                title: const Text('Sent campaigns'), trailing: Text('$sent')),
          ],
        );
      },
      loading: () => const AksharaLoadingState(),
      error: (error, _) =>
          AksharaErrorState.fromFailure(apiFailureMapper.fromException(error)),
    );
  }
}

/// COM-1/COM-3: per-broadcast delivery report with counts, unread roster, a
/// resend-to-unread action, and a CSV export (XCT-1 shared grid export).
class BroadcastReportScreen extends ConsumerWidget {
  const BroadcastReportScreen({required this.broadcastId, super.key});

  final String broadcastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportState = ref.watch(
      communicationBroadcastReportFutureProvider(broadcastId),
    );
    final resending = ref.watch(resendBroadcastProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast report'),
        actions: [
          reportState.maybeWhen(
            data: (report) => IconButton(
              key: QaTestKeys.communicationBroadcastReportExportButton,
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export CSV',
              onPressed: () => _exportCsv(context, report),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: reportState.when(
        data: (report) => _ReportBody(
          report: report,
          resending: resending,
          onResend: () => _resend(context, ref),
        ),
        loading: () => const AksharaLoadingState(),
        error: (error, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(error),
        ),
      ),
    );
  }

  Future<void> _resend(BuildContext context, WidgetRef ref) async {
    await ref.read(resendBroadcastProvider.notifier).execute(broadcastId);
    if (!context.mounted) return;
    final resent = ref.read(resendBroadcastProvider).valueOrNull;
    if (resent != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$resent resent')),
      );
    }
  }

  Future<void> _exportCsv(
    BuildContext context,
    BroadcastDeliveryReport report,
  ) async {
    const service = AksharaReportExportService();
    final rows = <List<String>>[
      ['Total', '${report.counts.total}', ''],
      ['Sent', '${report.counts.sent}', ''],
      ['Failed', '${report.counts.failed}', ''],
      ['Pending', '${report.counts.pending}', ''],
      ['Read', '${report.counts.read}', ''],
      ['Unread', '${report.counts.unread}', ''],
      ['Acknowledged', '${report.counts.acknowledged}', ''],
      for (final recipient in report.unreadRecipients)
        ['Unread recipient', recipient.name, recipient.userId],
    ];
    await service.shareGridCsv(
      filename: 'broadcast_${report.id}_report',
      headers: const ['Metric', 'Value', 'User'],
      rows: rows,
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.report,
    required this.resending,
    required this.onResend,
  });

  final BroadcastDeliveryReport report;
  final bool resending;
  final Future<void> Function() onResend;

  @override
  Widget build(BuildContext context) {
    final counts = report.counts;
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        Text(
          report.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text('${report.audience} · ${report.status}'),
        const SizedBox(height: 16),
        _CountTile(label: 'Total', value: counts.total),
        _CountTile(label: 'Sent', value: counts.sent),
        _CountTile(label: 'Failed', value: counts.failed),
        _CountTile(label: 'Pending', value: counts.pending),
        _CountTile(label: 'Read', value: counts.read),
        _CountTile(label: 'Unread', value: counts.unread),
        if (report.requiresAck)
          _CountTile(label: 'Acknowledged', value: counts.acknowledged),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: QaTestKeys.communicationBroadcastReportResendButton,
          onPressed: resending ? null : onResend,
          icon: resending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_outlined),
          label: const Text('Resend to unread'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Unread recipients',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (report.unreadRecipients.isEmpty)
          const Text('Everyone has read this broadcast.')
        else
          for (final recipient in report.unreadRecipients)
            ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline),
              title: Text(recipient.name),
            ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        '$value',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _formatSchedule(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}
