import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../feedback/akshara_haptics.dart';

/// P2-UX-2 §2.4 — the honest counterpart to [AksharaSuccessView]: the "queued"
/// beat for a money action that was recorded OFFLINE and is waiting to sync.
///
/// It must never masquerade as a confirmed success — no green tick, no receipt
/// number — because an offline collection is not yet server-confirmed (Data
/// Reliability Platform, refinement R1). Instead it shows an amber "queued"
/// glyph, states plainly that the receipt is issued only after the sync
/// confirms, and fires the warning haptic ([AksharaHaptics.warning]) once on
/// show so a queued outcome always *feels* different from a completed one.
///
/// Presentational only (no providers) — callers pass already-formatted strings.
class AksharaQueuedView extends StatefulWidget {
  const AksharaQueuedView({
    super.key,
    required this.title,
    this.highlight,
    this.subtitle,
    this.caption,
    this.icon = Icons.cloud_upload_outlined,
    this.primaryLabel,
    this.onPrimary,
  });

  /// The headline, e.g. "Payment queued".
  final String title;

  /// A large highlighted figure in the warning colour, e.g. the amount.
  final String? highlight;

  /// A supporting line, e.g. "Saved offline — will sync when you're back online".
  final String? subtitle;

  /// A smaller centred caption, e.g. "Cash · pending sync".
  final String? caption;

  final IconData icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  @override
  State<AksharaQueuedView> createState() => _AksharaQueuedViewState();
}

class _AksharaQueuedViewState extends State<AksharaQueuedView> {
  @override
  void initState() {
    super.initState();
    // The queued beat — deliberately the warning haptic, not success: the money
    // is safely captured but the transaction is NOT confirmed yet.
    AksharaHaptics.warning();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s6),
        child: Semantics(
          container: true,
          label: widget.title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 64, color: ext.warning),
              const SizedBox(height: AksharaSpacing.s4),
              Text(
                widget.title,
                style: text.titleLarge.copyWith(color: colors.onSurface),
              ),
              if (widget.highlight != null) ...[
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  widget.highlight!,
                  style: text.headlineSmall.copyWith(color: ext.warning),
                ),
              ],
              if (widget.subtitle != null) ...[
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  widget.subtitle!,
                  style:
                      text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (widget.caption != null)
                Text(
                  widget.caption!,
                  style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              if (widget.primaryLabel != null) ...[
                const SizedBox(height: AksharaSpacing.s4),
                FilledButton(
                  onPressed: widget.onPrimary,
                  child: Text(widget.primaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
