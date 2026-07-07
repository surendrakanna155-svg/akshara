import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  /// When false, the chip is invisible while online and only appears offline.
  final bool showWhenLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(aksharaFreshnessOnlineProvider);

    if (online && !showWhenLive) {
      return const SizedBox.shrink();
    }

    final ext = context.akshara;

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

    return Semantics(
      label: online ? 'Data is live' : 'Offline — showing saved data',
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
