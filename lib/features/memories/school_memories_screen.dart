import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/permissions.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/akshara_empty_state.dart';
import '../../shared/widgets/akshara_error_state.dart';
import '../../shared/widgets/akshara_loading_state.dart';
import '../../shared/widgets/akshara_manage_action.dart';
import '../phase5/phase5_providers.dart';
import 'memories_mutations_provider.dart';
import 'school_memory_event_screen.dart';
import '../../theme/spacing.dart';

class SchoolMemoriesScreen extends ConsumerWidget {
  const SchoolMemoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_schoolMemoriesTabProvider);
    final events = ref.watch(schoolMemoriesEventsProvider);

    return Scaffold(
      key: QaTestKeys.schoolMemoriesScreen,
      appBar: AppBar(title: const Text('School Memories')),
      floatingActionButton: AksharaManageAction(
        permission: Permission.manageSchoolMemories,
        child: FloatingActionButton.extended(
          key: QaTestKeys.schoolMemoriesCreateFab,
          onPressed: () => _showCreateEventDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Create event'),
        ),
      ),
      body: events.when(
        data: (items) {
          final filtered = items.where((event) {
            final status = event.status.toLowerCase();
            return selectedTab == 0 ? status == 'draft' : status == 'published';
          }).toList(growable: false);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AksharaSpacing.s4, AksharaSpacing.s4, AksharaSpacing.s4, AksharaSpacing.s2),
                child: SegmentedButton<int>(
                  key: QaTestKeys.schoolMemoriesStatusTabs,
                  segments: const [
                    ButtonSegment<int>(value: 0, label: Text('Draft')),
                    ButtonSegment<int>(value: 1, label: Text('Published')),
                  ],
                  selected: {selectedTab},
                  onSelectionChanged: (selection) {
                    ref.read(_schoolMemoriesTabProvider.notifier).state =
                        selection.first;
                  },
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? AksharaEmptyState(
                        message: selectedTab == 0
                            ? 'No draft events yet. Create one to start collecting media.'
                            : 'No published events yet.',
                        actionLabel: selectedTab == 0 ? 'Create event' : null,
                        onAction: selectedTab == 0
                            ? () => _showCreateEventDialog(context, ref)
                            : null,
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final event = filtered[index];
                          return ListTile(
                            key: QaTestKeys.schoolMemoriesEventTile(event.id),
                            title: Text(event.title),
                            subtitle:
                                Text('${event.category} · ${event.eventDate}'),
                            trailing:
                                Chip(label: Text(_titleCase(event.status))),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    SchoolMemoryEventScreen(eventId: event.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState(
          message: 'Could not load memories: $e',
          onRetry: () => ref.invalidate(schoolMemoriesEventsProvider),
        ),
      ),
    );
  }
}

final _schoolMemoriesTabProvider = StateProvider<int>((_) => 0);

Future<void> _showCreateEventDialog(
  BuildContext parentContext,
  WidgetRef ref,
) async {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  var category = 'general';

  await showDialog<void>(
    context: parentContext,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create school memory event'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: QaTestKeys.schoolMemoriesCreateTitleField,
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: QaTestKeys.schoolMemoriesCreateCategoryField,
                    initialValue: category,
                    items: const [
                      DropdownMenuItem(
                          value: 'general', child: Text('General')),
                      DropdownMenuItem(
                          value: 'annual_day', child: Text('Annual Day')),
                      DropdownMenuItem(
                          value: 'sports_day', child: Text('Sports Day')),
                      DropdownMenuItem(
                          value: 'graduation', child: Text('Graduation')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => category = value);
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: QaTestKeys.schoolMemoriesCreateDescriptionField,
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: QaTestKeys.schoolMemoriesCreateSubmitButton,
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;
                  final notifier =
                      ref.read(createSchoolMemoryEventProvider.notifier);
                  final result = await notifier.execute(
                    CreateSchoolMemoryEventRequest(
                      title: title,
                      category: category,
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                    ),
                  );
                  if (!parentContext.mounted || result == null) return;
                  Navigator.of(context).pop();
                  ref.read(_schoolMemoriesTabProvider.notifier).state = 0;
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      key: QaTestKeys.schoolMemoriesCreatedSnackbar,
                      content: Text('School memory event created.'),
                    ),
                  );
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}
