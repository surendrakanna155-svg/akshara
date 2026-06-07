import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../management_models.dart';
import '../management_providers.dart';
import '../widgets/management_module_scaffold.dart';

/// MG-08 — Management settings.
class ManagementSettingsScreen extends ConsumerWidget {
  const ManagementSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(managementSettingsLoadingProvider);
    final isError = ref.watch(managementSettingsErrorProvider);
    final data = ref.watch(managementSettingsProvider);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Management settings'),
        Text(
          'Academic year ${data.academicYear}',
          style: context.aksharaText.bodyMedium,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        for (final section in data.sections) ...[
          _SettingsSection(section: section),
          const SizedBox(height: AksharaSpacing.s6),
        ],
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.section});

  final ManagementSettingsSection section;

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
                  _SettingItemTile(item: section.items[i]),
                  if (i < section.items.length - 1)
                    const Divider(height: 1),
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
  const _SettingItemTile({required this.item});

  final ManagementSettingItem item;

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
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit ${item.label}',
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}
