import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme_extensions.dart';
import 'app_lock_controller.dart';
import 'app_lock_providers.dart';

/// P1-SEC-1 — the full-screen App Lock overlay. Rendered ON TOP of the app
/// content whenever [AppLockState.locked]; hides everything behind it and
/// prompts for the device biometric. Only a successful unlock removes it (no
/// PIN/passcode fallback). Auto-prompts on first appearance so the user does not
/// have to tap twice.
class AppLockOverlay extends ConsumerStatefulWidget {
  const AppLockOverlay({super.key});

  @override
  ConsumerState<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends ConsumerState<AppLockOverlay> {
  bool _prompting = false;
  bool _lastAttemptFailed = false;

  @override
  void initState() {
    super.initState();
    // Auto-prompt once the overlay is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    if (_prompting) return;
    setState(() {
      _prompting = true;
      _lastAttemptFailed = false;
    });
    final ok = await ref.read(appLockControllerProvider.notifier).unlock();
    if (!mounted) return;
    setState(() {
      _prompting = false;
      _lastAttemptFailed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = context.aksharaText;
    return Material(
      key: const Key('app-lock-overlay'),
      color: scheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: scheme.primary),
              const SizedBox(height: 16),
              Text('Akshara is locked', style: text.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Unlock with your biometric to continue.',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (_lastAttemptFailed) ...[
                const SizedBox(height: 8),
                Text(
                  'Biometric not verified. Try again.',
                  key: const Key('app-lock-failed'),
                  style: text.bodySmall.copyWith(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('app-lock-unlock-button'),
                onPressed: _prompting ? null : _attempt,
                icon: _prompting
                    ? const SizedBox(
                        height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
