import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../feedback/akshara_haptics.dart';

/// P2-UX-1 — the shared "success ceremony". One consistent, reassuring beat for
/// a completed submit / collect / save / approval: a success glyph, a title, an
/// optional highlighted figure (e.g. the amount), supporting lines, and up to
/// two actions. Fires the success haptic ([AksharaHaptics.success]) once on
/// show, so every success surface feels the same by construction.
///
/// Presentational only (no providers) — callers pass already-formatted strings.
class AksharaSuccessView extends StatefulWidget {
  const AksharaSuccessView({
    super.key,
    required this.title,
    this.highlight,
    this.subtitle,
    this.caption,
    this.icon = Icons.check_circle,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// The headline, e.g. "Payment successful".
  final String title;

  /// A large highlighted figure in the primary colour, e.g. the amount.
  final String? highlight;

  /// A supporting line, e.g. "Receipt DPS-000123".
  final String? subtitle;

  /// A smaller centred caption, e.g. "Cash · 12 Jul 2026".
  final String? caption;

  final IconData icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  State<AksharaSuccessView> createState() => _AksharaSuccessViewState();
}

class _AksharaSuccessViewState extends State<AksharaSuccessView> {
  @override
  void initState() {
    super.initState();
    // The success beat — fired once when the ceremony appears.
    AksharaHaptics.success();
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
              Icon(widget.icon, size: 64, color: ext.success),
              const SizedBox(height: AksharaSpacing.s4),
              Text(
                widget.title,
                style: text.titleLarge.copyWith(color: colors.onSurface),
              ),
              if (widget.highlight != null) ...[
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  widget.highlight!,
                  style: text.headlineSmall.copyWith(color: colors.primary),
                ),
              ],
              if (widget.subtitle != null) ...[
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  widget.subtitle!,
                  style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
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
              if (widget.secondaryLabel != null) ...[
                const SizedBox(height: AksharaSpacing.s2),
                TextButton(
                  onPressed: widget.onSecondary,
                  child: Text(widget.secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
