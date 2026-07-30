import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/liveness/data_freshness.dart';
import '../../core/liveness/data_freshness_providers.dart';
import '../../core/reliability/reliability_providers.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Live online/offline signal for freshness surfaces.
///
/// Reads the lightweight [ConnectivityService] directly (its current [isOnline]
/// flag + [onStatusChange] stream) rather than the full sync controller — so a
/// freshness chip never drags in the sync engine / outbox reachability timer.
/// Exposed as its own provider so surfaces (and tests) depend on the boolean
/// without touching connectivity internals.
final aksharaFreshnessOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  final sub = connectivity.onStatusChange.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return connectivity.isOnline;
});

/// A2 (Product Excellence Master Plan §Band A) — a small trust chip that makes
/// the reliability layer VISIBLE on money / attendance surfaces: is what you're
/// looking at live, or a saved copy from when you were last online?
///
/// It reads the REAL connectivity state from the sync center (no fabricated
/// freshness): online → a subtle "Live" state; offline → an honest amber
/// "Offline · saved data" state — offline honesty presented as a feature, not an
/// apology. Set [showWhenLive] to false to render nothing while live (surfaces
/// that only want to flag the degraded case).
class AksharaFreshnessChip extends ConsumerWidget {
  const AksharaFreshnessChip({
    super.key,
    this.showWhenLive = true,
    this.surfacePath,
  });

  /// When false, the chip is invisible while online and only appears offline.
  final bool showWhenLive;

  /// The API path whose freshness this chip reports, e.g.
  /// `/management/dashboard`.
  ///
  /// When null the chip falls back to the old connectivity-only behaviour.
  /// Supply it wherever the distinction matters — connectivity answers "can we
  /// reach the server?", which is NOT the same question as "is what you are
  /// looking at current?". A device can be online while the screen shows a body
  /// replayed from a 23-hour-old cache entry.
  final String? surfacePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(aksharaFreshnessOnlineProvider);
    final ext = context.akshara;

    // Freshness-aware path: five honest states, driven by what the network
    // layer actually observed (see core/liveness/data_freshness.dart).
    if (surfacePath != null) {
      final state = ref.watch(dataFreshnessProvider(surfacePath!));
      if (!state.isStale &&
          state.freshness == DataFreshness.live &&
          !showWhenLive) {
        return const SizedBox.shrink();
      }
      final p = presentFreshness(state);
      final (Color fg2, Color bg2, IconData icon2) = switch (p.tone) {
        FreshnessTone.good => (
            ext.success,
            ext.successContainer.withValues(alpha: 0.6),
            Icons.cloud_done_outlined,
          ),
        FreshnessTone.neutral => (
            context.colors.onSurfaceVariant,
            context.colors.surfaceContainerHighest,
            Icons.schedule_outlined,
          ),
        FreshnessTone.warning => (
            ext.warning,
            ext.warningContainer.withValues(alpha: 0.7),
            state.freshness == DataFreshness.refreshFailed
                ? Icons.sync_problem_outlined
                : Icons.cloud_off_outlined,
          ),
      };
      return _chip(context, fg2, bg2, icon2, p.label, p.semanticLabel);
    }

    if (online && !showWhenLive) {
      return const SizedBox.shrink();
    }

    final (Color fg, Color bg, IconData icon, String label) = online
        ? (
            ext.success,
            ext.successContainer.withValues(alpha: 0.6),
            Icons.cloud_done_outlined,
            'Live',
          )
        : (
            ext.warning,
            ext.warningContainer.withValues(alpha: 0.7),
            Icons.cloud_off_outlined,
            'Offline · saved data',
          );

    return _chip(
      context,
      fg,
      bg,
      icon,
      label,
      online ? 'Data is live' : 'Offline — showing saved data',
    );
  }

  Widget _chip(
    BuildContext context,
    Color fg,
    Color bg,
    IconData icon,
    String label,
    String semanticLabel,
  ) {
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AksharaSpacing.s2,
          vertical: AksharaSpacing.s1,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AksharaRadius.full),
          border: Border.all(color: fg.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: AksharaSpacing.s1),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
