import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/app_lock/app_lock_providers.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/akshara_section_header.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../../theme/theme_mode_provider.dart';
import '../../theme/theme_mode_storage.dart';

/// Settings → Appearance — Light / Dark / System theme preference (Phase C.2).
///
/// Owner decision: appearance is configured here in settings only (no app-bar
/// quick toggle). The preference is device-level and applies immediately.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final text = context.aksharaText;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Text(
            'Choose how Akshara looks. Your choice is saved on this device and '
            'applies right away.',
            style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Theme'),
          for (final option in _AppearanceOption.values) ...[
            _AppearanceTile(
              option: option,
              selected: mode == option.mode,
              onTap: () => ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(option.mode),
            ),
            const SizedBox(height: AksharaSpacing.s2),
          ],
          const SizedBox(height: AksharaSpacing.s2),
          Material(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AksharaSpacing.s2),
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              child: Text(
                'System follows your phone\'s light or dark setting automatically.',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s6),
          const AksharaSectionHeader(title: 'Security'),
          const _AppLockTile(),
        ],
      ),
    );
  }
}

/// P1-SEC-1 — the App Lock toggle. Enabling requires a successful biometric
/// prompt first (so a user with no enrolled biometric can't lock themselves
/// out); the controller enforces that and this tile surfaces the outcome.
class _AppLockTile extends ConsumerStatefulWidget {
  const _AppLockTile();

  @override
  ConsumerState<_AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends ConsumerState<_AppLockTile> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ref.read(appLockControllerProvider.notifier).setEnabled(value);
    if (!mounted) return;
    setState(() => _busy = false);
    if (value && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't turn on App Lock — enrol a biometric (Face ID / fingerprint) "
            'on your device and verify it.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(appLockControllerProvider.select((s) => s.enabled));
    final text = context.aksharaText;
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: AksharaRadius.card,
      child: SwitchListTile(
        key: const Key('app-lock-toggle'),
        value: enabled,
        onChanged: _busy ? null : _toggle,
        secondary: Icon(Icons.lock_outline, color: colors.onSurfaceVariant),
        title: Text('App Lock', style: text.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Require your device biometric to open Akshara after it has been in the '
          'background. No PIN fallback.',
          style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// The three appearance choices, mapped to [ThemeMode].
enum _AppearanceOption {
  light(ThemeMode.light, 'Light', 'Bright surfaces — the premium default.',
      Icons.light_mode_outlined),
  dark(ThemeMode.dark, 'Dark', 'Dimmed surfaces, easier on the eyes at night.',
      Icons.dark_mode_outlined),
  system(ThemeMode.system, 'System',
      'Match your device\'s light or dark setting.', Icons.brightness_auto_outlined);

  const _AppearanceOption(this.mode, this.label, this.description, this.icon);

  final ThemeMode mode;
  final String label;
  final String description;
  final IconData icon;
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _AppearanceOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: AksharaRadius.card,
      child: InkWell(
        key: QaTestKeys.appearanceModeOption(themeModeStorageKey(option.mode)),
        borderRadius: AksharaRadius.card,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          decoration: BoxDecoration(
            borderRadius: AksharaRadius.card,
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                option.icon,
                color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: text.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? colors.onPrimaryContainer : colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.description,
                      style: text.bodySmall.copyWith(
                        color: selected
                            ? colors.onPrimaryContainer.withValues(alpha: 0.8)
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: AksharaSpacing.s2),
                Icon(Icons.check_circle, color: colors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
