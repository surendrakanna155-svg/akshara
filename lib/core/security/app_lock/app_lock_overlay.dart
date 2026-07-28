import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme_extensions.dart';
import '../../../theme/typography.dart';
import '../../constants/app_constants.dart';
import 'app_lock_providers.dart';

/// P1-SEC-1 — the full-screen App Lock overlay. Rendered ON TOP of the app
/// content whenever [AppLockState.locked]; it must hide AND fully block
/// everything behind it — no taps (audit F2) — and offer a sign-out ESCAPE so a
/// user whose biometric was later removed / OS-locked is never permanently
/// locked out (audit F3 / P0-1). Only a successful biometric unlock (no PIN
/// fallback) or an explicit sign-out removes it. Auto-prompts once on first
/// appearance.
///
/// The confirm-before-sign-out uses an INLINE two-step (not `showDialog`): this
/// overlay is mounted in the `MaterialApp.router` builder, ABOVE GoRouter's
/// Navigator, so `showDialog`/`Navigator.of(context)` have no Navigator ancestor
/// and throw — which silently broke the F3 escape (audit P0-1). The inline
/// confirm needs no Navigator and works in every tree.
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
  bool _confirmingSignOut = false;

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
    try {
      final ok = await ref.read(appLockControllerProvider.notifier).unlock();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastAttemptFailed = !ok;
      });
    } catch (_) {
      // audit P3: a throwing authenticator must not strand the UI with _busy
      // stuck true (which would disable Unlock AND Sign out). Fail-safe: stay
      // locked, re-enable the buttons, surface the retry/sign-out hint.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastAttemptFailed = true;
      });
    }
  }

  Future<void> _confirmSignOut() async {
    if (_busy || !mounted) return; // symmetry with _attempt's re-entrancy guard
    // Inline confirm (audit P0-1): no Navigator/showDialog dependency.
    setState(() {
      _busy = true;
      _confirmingSignOut = false;
    });
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
    // The opaque full-screen Material + AbsorbPointer background swallow every
    // tap that isn't on the card, so nothing behind is interactable (F2). The
    // Android back button is intentionally NOT intercepted (audit P2-2): a
    // builder-level widget has neither a ModalRoute nor a Router ancestor, so
    // PopScope/BackButtonListener can't register here. It's safe — this overlay
    // is driven by lock STATE, not the route stack, so back only navigates the
    // hidden route beneath it (still covered) or backgrounds the app.
    return Material(
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
              child: _confirmingSignOut
                  ? _buildSignOutConfirm(context, scheme, text)
                  : _buildLockCard(context, scheme, text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockCard(
    BuildContext context,
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 48, color: scheme.primary),
        const SizedBox(height: 16),
        Text('${AppConstants.appName} is locked', style: text.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Unlock with your biometric to continue.',
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
        if (_lastAttemptFailed) ...[
          const SizedBox(height: 8),
          Text(
            "Biometric not verified. Try again, or sign out if you can't use it.",
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
          onPressed: _busy ? null : () => setState(() => _confirmingSignOut = true),
          child: const Text('Sign out instead'),
        ),
      ],
    );
  }

  Widget _buildSignOutConfirm(
    BuildContext context,
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.logout, size: 48, color: scheme.primary),
        const SizedBox(height: 16),
        Text('Sign out?', style: text.titleMedium),
        const SizedBox(height: 8),
        Text(
          "Can't unlock? Signing out clears this session and turns off App Lock "
          'so you can sign in again.',
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('app-lock-signout-confirm'),
          onPressed: _busy ? null : _confirmSignOut,
          child: _busy
              ? const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Sign out'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('app-lock-signout-cancel'),
          onPressed: _busy ? null : () => setState(() => _confirmingSignOut = false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
