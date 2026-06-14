import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'ai_access_mode.dart';
import 'ai_access_preferences_provider.dart';

/// Settings → AI Assistant — access mode preferences (INTEL-05).
class AiAssistantSettingsScreen extends ConsumerWidget {
  const AiAssistantSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(aiAccessPreferencesProvider);
    final text = context.aksharaText;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Text(
            'Choose how Akshara AI appears. Preferences are saved for your account on this device.',
            style: text.bodyMedium.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Access mode'),
          for (final mode in AiAccessMode.values)
            ListTile(
              key: QaTestKeys.aiAccessModeOption(mode.storageKey),
              title: Text(mode.label),
              subtitle: Text(_modeDescription(mode)),
              trailing: prefs.mode == mode
                  ? Icon(Icons.check_circle, color: context.colors.primary)
                  : null,
              onTap: () =>
                  ref.read(aiAccessPreferencesProvider.notifier).setMode(mode),
            ),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Floating bubble'),
          SwitchListTile(
            key: QaTestKeys.aiAccessFloatingBubbleToggle,
            value: prefs.floatingBubbleEnabled,
            onChanged: (value) => ref
                .read(aiAccessPreferencesProvider.notifier)
                .setFloatingBubbleEnabled(value),
            title: const Text('Show optional floating bubble'),
            subtitle: const Text(
              'Keep the floating AI dock visible alongside your primary access mode.',
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          Material(
            key: QaTestKeys.aiAccessSyncNote,
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AksharaSpacing.s2),
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              child: Text(
                'Cross-device sync will apply when the user-preferences API is connected. '
                'Changes apply immediately on this device.',
                style: text.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _modeDescription(AiAccessMode mode) => switch (mode) {
        AiAccessMode.floatingBubble => 'Floating dock on every screen.',
        AiAccessMode.bottomNavCenter => 'Center button in mobile bottom navigation.',
        AiAccessMode.sidebarEntry => 'Dedicated entry in the ERP sidebar or drawer.',
        AiAccessMode.appBarAction => 'AI icon in the top app bar.',
        AiAccessMode.auto =>
          'Mobile: bottom nav center. Desktop/tablet: sidebar entry.',
      };
}
