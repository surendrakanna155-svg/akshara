import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../transport_models.dart';
import '../transport_providers.dart';
import '../widgets/transport_module_scaffold.dart';

/// TR-09 — Transport Settings.
class TransportSettingsScreen extends ConsumerWidget {
  const TransportSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(transportSettingsLoadingProvider);
    final isError = ref.watch(transportSettingsErrorProvider);
    final data = ref.watch(transportSettingsProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.settings,
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
    required TransportSettingsData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading transport settings',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load transport settings.',
      );
    }

    if (data == null) {
      return const AksharaErrorState(
        message: 'Transport settings are not configured.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Transport settings'),
        Text(
          'Default shift: ${data.defaultShift.name.toUpperCase()}',
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

  final TransportSettingsSection section;

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

  final TransportSettingItem item;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      label: '${item.label}: ${item.value}',
      child: ListTile(
        title: Text(item.label, style: text.titleSmall),
        subtitle: Text(
          '${item.description}\n${item.value}',
          style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
        ),
        // STF-8: edit affordance removed — no client/backend write path exists,
        // so a no-op "Edit" misleads users. Settings remain read-only.
      ),
    );
  }
}
