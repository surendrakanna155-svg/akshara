import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme_extensions.dart';
import 'app_lock_providers.dart';

/// P1-SEC-1 — the full-screen App Lock overlay. Rendered ON TOP of the app
/// content whenever [AppLockState.locked]; it must hide AND fully block
/// everything behind it — no taps, no back button (audit F2) — and offer a
/// sign-out ESCAPE so a user whose biometric was later removed / OS-locked is
/// never permanently locked out (audit F3). Only a successful biometric unlock
/// (no PIN fallback) or an explicit sign-out removes it. Auto-prompts once on
/// first appearance.
class AppLockOverlay extends ConsumerStatefulWidget {
  const AppLockOverlay({super.key, required this.onSignOut});

  /// Clears the session AND disables App Lock — the recovery path from a
  /// biometric-removed lock-out. Supplied by the app shell (keeps `core` free of
  /// a `features/auth` dependency). Safe because signing out destroys the very
  /// session the lock protects.
  final Future<void> Function() onSignOut;

  @override
  ConsumerState<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends ConsumerState<AppLockOverlay> {
  bool _busy = false;
  bool _lastAttemptFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    if (_busy || !mounted) return; // audit F5: guard the pre-await setState too
    setState(() {
      _busy = true;
      _lastAttemptFailed = false;
    });
    final ok = await ref.read(appLockControllerProvider.notifier).unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastAttemptFailed = !ok;
    });
  }

  Future<void> _signOut() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          "Can't unlock? Signing out clears this session and turns off App Lock "
          'so you can sign in again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('app-lock-signout-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      // On success the session is cleared + App Lock disabled → the state change
      // tears down this overlay. If it does NOT (sign-out failed), reset busy so
      // the user isn't stranded on a frozen lock screen.
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = context.aksharaText;
    // canPop:false blocks the Android back button from popping the router behind
    // the lock; the opaque full-screen Material + AbsorbPointer background swallow
    // every tap that isn't on the card, so nothing behind is interactable (F2).
    return PopScope(
      canPop: false,
      child: Material(
        key: const Key('app-lock-overlay'),
        color: scheme.surface,
        child: Stack(
          children: [
            // Full-screen tap absorber — a bare Material does NOT hit-test its
            // empty area, so without this, taps in the margins fall through to
            // the content below (audit F2).
            const Positioned.fill(
              child: AbsorbPointer(child: SizedBox.expand()),
            ),
            Center(
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
                        "Biometric not verified. Try again, or sign out if you "
                        "can't use it.",
                        key: const Key('app-lock-failed'),
                        style: text.bodySmall.copyWith(color: scheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('app-lock-unlock-button'),
                      onPressed: _busy ? null : _attempt,
                      icon: _busy
                          ? const SizedBox(
                              height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.fingerprint),
                      label: const Text('Unlock'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('app-lock-signout-button'),
                      onPressed: _busy ? null : _signOut,
                      child: const Text('Sign out instead'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
