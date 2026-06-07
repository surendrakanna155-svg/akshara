import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../finance_workflow_actions.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_settings_provider.dart';

/// FN-11 — Finance module settings.
class FinanceSettingsScreen extends ConsumerWidget {
  const FinanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(financeSettingsViewStateProvider);

    return FinanceModuleScaffold(
      screen: FinanceScreen.settings,
      showFilterBar: false,
      body: FinanceAsyncBody<FinanceSettingsData>(
        state: viewState,
        loadingLabel: 'Loading finance settings',
        emptyMessage: 'Finance settings are not configured.',
        emptyIcon: Icons.settings_outlined,
        onRetry: () => retryFinanceFuture(ref, financeSettingsFutureProvider),
        builder: (data) => _buildContent(context, ref: ref, data: data),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required WidgetRef ref,
    required FinanceSettingsData data,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Finance settings'),
        Text(
          'Academic year ${data.academicYear}',
          style: context.aksharaText.bodyMedium,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        for (final section in data.sections) ...[
          _SettingsSection(section: section, ref: ref),
          const SizedBox(height: AksharaSpacing.s6),
        ],
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.section, required this.ref});

  final FinanceSettingsSection section;
  final WidgetRef ref;

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
                    item: section.items[i],
                    sectionId: section.id,
                    ref: ref,
                  ),
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
  const _SettingItemTile({
    required this.item,
    required this.sectionId,
    required this.ref,
  });

  final FinanceSettingItem item;
  final String sectionId;
  final WidgetRef ref;

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
                onPressed: () => showEditFinanceSettingDialog(
                  context,
                  ref,
                  item: item,
                  sectionId: sectionId,
                ),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit ${item.label}',
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}
