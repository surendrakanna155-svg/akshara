import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../theme/spacing.dart';
import 'school_calendar_models.dart';
import 'school_calendar_providers.dart';

/// PRA-P1-17 — School holiday/event calendar.
///
/// Read gates on [Permission.viewSchoolCalendar]; the add/delete affordances
/// gate on [Permission.manageSchoolCalendar]. Writes flow to the backend
/// `POST/DELETE /school-calendar`, which populates `school_calendar_events` so
/// downstream attendance holiday-block and HR holiday-exclusion can fire.
class SchoolCalendarScreen extends ConsumerWidget {
  const SchoolCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbac = ref.watch(rbacServiceProvider);
    final canView = rbac.hasPermission(Permission.viewSchoolCalendar);
    final canManage = rbac.hasPermission(Permission.manageSchoolCalendar);

    if (!canView) {
      return Scaffold(
        appBar: AppBar(title: const Text('School calendar')),
        body: const AksharaEmptyState(
          message:
              'You do not have permission to view the school calendar. Ask an '
              'administrator for the "View school calendar" permission.',
          icon: Icons.lock_outline,
        ),
      );
    }

    final eventsAsync = ref.watch(schoolCalendarEventsProvider);
    final filter = ref.watch(schoolCalendarFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School calendar'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(schoolCalendarEventsProvider),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openAddSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add event'),
            )
          : null,
      body: Column(
        children: [
          _FilterBar(
            selected: filter,
            onChanged: (value) =>
                ref.read(schoolCalendarFilterProvider.notifier).state = value,
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(schoolCalendarEventsProvider),
              child: ErpAsyncBody<List<SchoolCalendarEvent>>(
                state: resolveErpAsync(
                  eventsAsync,
                  isDataEmpty: (data) => data.isEmpty,
                ),
                loadingLabel: 'Loading calendar',
                emptyMessage: filter == null
                    ? 'No calendar events yet. Add holidays and events so '
                        'attendance and HR can honour them.'
                    : 'No ${filter.label.toLowerCase()} events. Change the '
                        'filter or add one.',
                emptyIcon: Icons.event_busy_outlined,
                onRetry: () => ref.invalidate(schoolCalendarEventsProvider),
                builder: (events) => ListView.separated(
                  padding: const EdgeInsets.all(AksharaSpacing.s4),
                  itemCount: events.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AksharaSpacing.s2),
                  itemBuilder: (context, index) => _EventTile(
                    event: events[index],
                    canManage: canManage,
                    onDelete: () => _confirmDelete(context, ref, events[index]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final input = await showModalBottomSheet<CreateSchoolCalendarEventInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddEventSheet(),
    );
    if (input == null) return;

    try {
      await ref.read(schoolCalendarRepositoryProvider).createEvent(
            query: ref.read(repositoryQueryProvider),
            input: input,
          );
      ref.invalidate(schoolCalendarEventsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Added "${input.title}".')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not add event: $error')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SchoolCalendarEvent event,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('Remove "${event.title}" from the calendar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(schoolCalendarRepositoryProvider).deleteEvent(
            query: ref.read(repositoryQueryProvider),
            id: event.id,
          );
      ref.invalidate(schoolCalendarEventsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted "${event.title}".')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete event: $error')),
      );
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final SchoolCalendarEventType? selected;
  final ValueChanged<SchoolCalendarEventType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s4,
        vertical: AksharaSpacing.s3,
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 20),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: DropdownButtonFormField<SchoolCalendarEventType?>(
              key: const Key('school_calendar_filter'),
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Event type',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<SchoolCalendarEventType?>(
                  value: null,
                  child: Text('All types'),
                ),
                for (final type in SchoolCalendarEventType.values)
                  DropdownMenuItem<SchoolCalendarEventType?>(
                    value: type,
                    child: Text(type.label),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.canManage,
    required this.onDelete,
  });

  final SchoolCalendarEvent event;
  final bool canManage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateLabel = event.isMultiDay
        ? '${formatCalendarDate(event.eventDate)} – '
            '${formatCalendarDate(event.endDate!)}'
        : formatCalendarDate(event.eventDate);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_iconFor(event.eventType), size: 20),
        ),
        title: Text(event.title),
        subtitle: Text(
          event.description == null || event.description!.isEmpty
              ? dateLabel
              : '$dateLabel\n${event.description}',
        ),
        isThreeLine:
            event.description != null && event.description!.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(event.eventType.label),
              visualDensity: VisualDensity.compact,
            ),
            if (canManage)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(SchoolCalendarEventType type) => switch (type) {
        SchoolCalendarEventType.holiday => Icons.beach_access_outlined,
        SchoolCalendarEventType.festival => Icons.celebration_outlined,
        SchoolCalendarEventType.event => Icons.event_outlined,
        SchoolCalendarEventType.exam => Icons.assignment_outlined,
        SchoolCalendarEventType.result => Icons.grading_outlined,
        SchoolCalendarEventType.admission => Icons.how_to_reg_outlined,
        SchoolCalendarEventType.achievement => Icons.emoji_events_outlined,
        SchoolCalendarEventType.general => Icons.push_pin_outlined,
      };
}

/// Bottom-sheet form for creating an event. Pops a
/// [CreateSchoolCalendarEventInput] on submit, or null on cancel.
class _AddEventSheet extends StatefulWidget {
  const _AddEventSheet();

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _eventDate = DateTime.now();
  DateTime? _endDate;
  SchoolCalendarEventType _eventType = SchoolCalendarEventType.holiday;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final initial = isEnd ? (_endDate ?? _eventDate) : _eventDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _endDate = picked;
      } else {
        _eventDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      }
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      CreateSchoolCalendarEventInput(
        eventDate: _eventDate,
        endDate: _endDate,
        title: _titleController.text.trim(),
        eventType: _eventType,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AksharaSpacing.s4,
        AksharaSpacing.s4,
        AksharaSpacing.s4,
        AksharaSpacing.s4 + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add calendar event',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AksharaSpacing.s4),
              TextFormField(
                key: const Key('school_calendar_title_field'),
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: AksharaSpacing.s4),
              DropdownButtonFormField<SchoolCalendarEventType>(
                key: const Key('school_calendar_type_field'),
                initialValue: _eventType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in SchoolCalendarEventType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) => setState(
                  () => _eventType = value ?? SchoolCalendarEventType.holiday,
                ),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Start date',
                      value: _eventDate,
                      onTap: () => _pickDate(isEnd: false),
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  Expanded(
                    child: _DateField(
                      label: 'End date (optional)',
                      value: _endDate,
                      onTap: () => _pickDate(isEnd: true),
                      onClear:
                          _endDate == null ? null : () => setState(() => _endDate = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s4),
              TextFormField(
                key: const Key('school_calendar_description_field'),
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AksharaSpacing.s5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AksharaSpacing.s2),
                  FilledButton(
                    key: const Key('school_calendar_submit_button'),
                    onPressed: _submit,
                    child: const Text('Save event'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(value == null ? 'Select' : formatCalendarDate(value!)),
      ),
    );
  }
}

/// `26 Jan 2026` — dependency-free display formatter.
String formatCalendarDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final month = months[(date.month - 1).clamp(0, 11)];
  return '${date.day} $month ${date.year}';
}
