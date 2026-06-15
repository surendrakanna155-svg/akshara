import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../management_models.dart';
import '../management_mutations_provider.dart';
import '../management_providers.dart';
import '../management_requests.dart';
import '../widgets/management_module_scaffold.dart';

/// MG-08 — Management settings.
class ManagementSettingsScreen extends ConsumerStatefulWidget {
  const ManagementSettingsScreen({super.key});

  @override
  ConsumerState<ManagementSettingsScreen> createState() =>
      _ManagementSettingsScreenState();
}

class _ManagementSettingsScreenState
    extends ConsumerState<ManagementSettingsScreen> {
  ManagementSettingsData? _draft;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(managementSettingsLoadingProvider);
    final isError = ref.watch(managementSettingsErrorProvider);
    final data = ref.watch(managementSettingsProvider);
    _draft ??= data;

    return ManagementModuleScaffold(
      screen: ManagementScreen.settings,
      showFilterBar: false,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required ManagementSettingsData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading management settings',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load management settings.',
      );
    }

    if (data == null) {
      return const AksharaErrorState(
        message: 'Management settings are not configured.',
      );
    }
    final draft = _draft ?? data;
    final isMutationLoading =
        ref.watch(updateManagementSettingsProvider).isLoading;
    final isSaving = _isSaving || isMutationLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: QaTestKeys.managementSettingsSaveButton,
            onPressed: isSaving ? null : _saveDraft,
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(isSaving ? 'Saving...' : 'Save settings'),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Management settings'),
        Row(
          children: [
            Expanded(
              child: Text(
                'Academic year ${draft.academicYear}',
                style: context.aksharaText.bodyMedium,
              ),
            ),
            IconButton(
              key: QaTestKeys.managementSettingsAcademicYearEditButton,
              onPressed: () => _editAcademicYear(draft.academicYear),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit academic year',
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s6),
        for (final section in draft.sections) ...[
          _SettingsSection(
            section: section,
            onEdit: _editSettingItem,
          ),
          const SizedBox(height: AksharaSpacing.s6),
        ],
        const AksharaSectionHeader(title: 'AI Assistant'),
        Card(
          elevation: 0,
          child: ListTile(
            key: QaTestKeys.aiAssistantSettingsLink,
            leading: const Icon(Icons.psychology_outlined),
            title: const Text('AI access modes'),
            subtitle: const Text(
                'Choose floating bubble, sidebar, app bar, or auto layout'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RouteNames.aiAssistantSettings),
          ),
        ),
      ],
    );
  }

  Future<void> _editAcademicYear(String value) async {
    final controller = TextEditingController(text: value);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit academic year'),
        content: TextField(
          key: QaTestKeys.managementSettingsDialogField,
          controller: controller,
          decoration: const InputDecoration(labelText: 'Academic year'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.managementSettingsDialogSaveButton,
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (next == null || next.isEmpty) return;
    setState(() {
      final draft = _draft;
      if (draft == null) return;
      _draft = ManagementSettingsData(
        academicYear: next,
        sections: draft.sections,
      );
    });
  }

  Future<void> _editSettingItem(
    ManagementSettingsSection section,
    ManagementSettingItem item,
  ) async {
    final controller = TextEditingController(text: item.value);
    final nextValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item.label}'),
        content: TextField(
          key: QaTestKeys.managementSettingsDialogField,
          controller: controller,
          decoration: InputDecoration(labelText: item.label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.managementSettingsDialogSaveButton,
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (nextValue == null || nextValue.isEmpty) return;
    setState(() {
      final draft = _draft;
      if (draft == null) return;
      _draft = ManagementSettingsData(
        academicYear: draft.academicYear,
        sections: [
          for (final existing in draft.sections)
            if (existing.id == section.id)
              ManagementSettingsSection(
                id: existing.id,
                title: existing.title,
                items: [
                  for (final existingItem in existing.items)
                    if (existingItem.id == item.id)
                      ManagementSettingItem(
                        id: existingItem.id,
                        label: existingItem.label,
                        value: nextValue,
                        description: existingItem.description,
                        editable: existingItem.editable,
                      )
                    else
                      existingItem,
                ],
              )
            else
              existing,
        ],
      );
    });
  }

  Future<void> _saveDraft() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _isSaving = true);
    final updates = <ManagementSettingUpdate>[
      for (final section in draft.sections)
        for (final item in section.items)
          ManagementSettingUpdate(
            sectionId: section.id,
            itemId: item.id,
            value: item.value,
          ),
    ];
    try {
      final saved =
          await ref.read(updateManagementSettingsProvider.notifier).execute(
                UpdateManagementSettingsRequest(
                  academicYear: draft.academicYear,
                  updates: updates,
                ),
              );
      if (saved != null) {
        setState(() => _draft = saved);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Management settings saved')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.section,
    required this.onEdit,
  });

  final ManagementSettingsSection section;
  final void Function(ManagementSettingsSection, ManagementSettingItem) onEdit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${section.title} settings, ${section.items.length} items',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AksharaSectionHeader(title: section.title),
          const SizedBox(height: AksharaSpacing.s3),
          Card(
            elevation: 0,
            child: Column(
              children: [
                for (var i = 0; i < section.items.length; i++) ...[
                  _SettingItemTile(
                    section: section,
                    item: section.items[i],
                    onEdit: onEdit,
                  ),
                  if (i < section.items.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingItemTile extends StatelessWidget {
  const _SettingItemTile({
    required this.section,
    required this.item,
    required this.onEdit,
  });

  final ManagementSettingsSection section;
  final ManagementSettingItem item;
  final void Function(ManagementSettingsSection, ManagementSettingItem) onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      label: '${item.label}: ${item.value}',
      child: ListTile(
        title: Text(item.label, style: text.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AksharaSpacing.s1),
            Text(item.value, style: text.bodyLarge),
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              item.description,
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        trailing: item.editable
            ? IconButton(
                key: QaTestKeys.managementSettingsItemEditButton(
                  '${section.id}_${item.id}',
                ),
                onPressed: () => onEdit(section, item),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit ${item.label}',
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}
