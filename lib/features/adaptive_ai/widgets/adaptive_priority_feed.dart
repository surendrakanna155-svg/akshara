// Adaptive AI (P3-AI-2 / W2) — the reusable per-persona priority/recommendation
// feed section. Backend-driven, deterministic (zero-token), explainable (every
// item shows its "why"). SELF-HIDING: renders nothing while loading, on error,
// or when the persona has no feed yet — so it never breaks a home screen and the
// deterministic content below it always shows. The pre-staged action opens a
// screen for the human to act on — AI never executes (governance rail).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../adaptive_ai_models.dart';
import '../adaptive_ai_providers.dart';

/// The overflow-menu choices on a feed row (P2-6 audit). Dismiss folds the
/// former standalone icon button in here to keep the dense row compact; Mute
/// records `suppress` (learn not to resurface this item TYPE for the persona).
enum _FeedItemMenuChoice { dismiss, suppress }

class AdaptivePriorityFeedSection extends ConsumerWidget {
  const AdaptivePriorityFeedSection({
    super.key,
    required this.persona,
    this.title = 'Priorities for you',
    this.onOpenAction,
    this.maxItems = 4,
  });

  final String persona;
  final String title;

  /// Invoked when the user taps a recommendation's pre-staged action. The host
  /// maps the (logical) deep link to real navigation; null hides action buttons.
  final void Function(BuildContext context, AdaptiveAction action)? onOpenAction;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adaptiveRecommendationsProvider(persona));
    return async.maybeWhen(
      data: (feed) => feed.isEmpty
          ? const SizedBox.shrink()
          : _section(context, ref, feed.items.take(maxItems).toList(), feed.degraded),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _section(
    BuildContext context,
    WidgetRef ref,
    List<AdaptivePriorityItem> items,
    bool degraded,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: context.colors.primary),
            const SizedBox(width: AksharaSpacing.s2),
            Text(title, style: context.aksharaText.titleSmall),
          ],
        ),
        // P2-2: honest partial-feed signal — the backend marks a feed `degraded`
        // when a source was skipped for lack of permission, so the list is a
        // subset. Surface it rather than silently showing a partial list as whole.
        if (degraded) ...[
          const SizedBox(height: AksharaSpacing.s1),
          Text(
            'Showing partial results — some data needs additional access.',
            style: context.aksharaText.bodySmall.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AksharaSpacing.s2),
        for (final item in items) ...[
          _AdaptiveRecommendationTile(
            item: item,
            onOpen: onOpenAction == null || item.action == null
                ? null
                : () {
                    // Learning signal (doc 04 §4 / P12): acting on a
                    // recommendation IS an accept. Fire-and-forget — the human
                    // is already navigating, so this must never block or fail
                    // the tap.
                    unawaited(recordAdaptiveFeedback(
                      ref,
                      persona: persona,
                      item: item,
                      action: AdaptiveFeedbackAction.accept,
                    ));
                    onOpenAction!(context, item.action!);
                  },
            onDismiss: () => recordAdaptiveFeedback(
              ref,
              persona: persona,
              item: item,
              action: AdaptiveFeedbackAction.dismiss,
            ),
            onSuppress: () => recordAdaptiveFeedback(
              ref,
              persona: persona,
              item: item,
              action: AdaptiveFeedbackAction.suppress,
            ),
          ),
          const SizedBox(height: AksharaSpacing.s2),
        ],
      ],
    );
  }
}

class _AdaptiveRecommendationTile extends StatefulWidget {
  const _AdaptiveRecommendationTile({
    required this.item,
    required this.onOpen,
    required this.onDismiss,
    required this.onSuppress,
  });

  final AdaptivePriorityItem item;
  final VoidCallback? onOpen;
  final VoidCallback onDismiss;
  final VoidCallback onSuppress;

  @override
  State<_AdaptiveRecommendationTile> createState() => _AdaptiveRecommendationTileState();
}

class _AdaptiveRecommendationTileState extends State<_AdaptiveRecommendationTile> {
  bool _breakdownExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = widget.item;
    final breakdown = item.factorBreakdown;
    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScoreBadge(score: item.score),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: context.aksharaText.bodyMedium),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      item.detail,
                      style: context.aksharaText.bodySmall.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Folds the former standalone "Dismiss" icon button into one
              // compact overflow menu — the feed rows are dense, and Mute
              // needs a home too (P2-6 audit).
              PopupMenuButton<_FeedItemMenuChoice>(
                icon: const Icon(Icons.more_vert, size: 18),
                tooltip: 'More options',
                onSelected: (choice) {
                  switch (choice) {
                    case _FeedItemMenuChoice.dismiss:
                      widget.onDismiss();
                    case _FeedItemMenuChoice.suppress:
                      widget.onSuppress();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _FeedItemMenuChoice.dismiss,
                    child: Text('Dismiss'),
                  ),
                  PopupMenuItem(
                    value: _FeedItemMenuChoice.suppress,
                    child: Text('Mute this type'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s1),
          InkWell(
            onTap: breakdown == null ? null : () => setState(() => _breakdownExpanded = !_breakdownExpanded),
            child: Row(
              children: [
                // Explainability rail — always show WHY this surfaced.
                Icon(Icons.info_outline, size: 13, color: colors.onSurfaceVariant),
                const SizedBox(width: AksharaSpacing.s1),
                Expanded(
                  child: Text(
                    'Why: ${item.reason}',
                    style: context.aksharaText.labelSmall.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
                if (breakdown != null)
                  Icon(
                    _breakdownExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                if (widget.onOpen != null && item.action != null)
                  TextButton(
                    onPressed: widget.onOpen,
                    child: Text(item.action!.label),
                  ),
              ],
            ),
          ),
          if (_breakdownExpanded && breakdown != null) ...[
            const SizedBox(height: AksharaSpacing.s1),
            Padding(
              padding: const EdgeInsets.only(left: AksharaSpacing.s5),
              child: Text(
                _formatFactorBreakdown(breakdown),
                style: context.aksharaText.labelSmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders the score factors as a compact "why is this first?" detail line,
/// e.g. `urgency ×2.4 · impact ×3.0 · recency ×1.1 · learned ×1.0`.
String _formatFactorBreakdown(AdaptiveFactorBreakdown breakdown) {
  String fmt(double v) => '×${v.toStringAsFixed(1)}';
  return 'urgency ${fmt(breakdown.urgency)} · '
      'impact ${fmt(breakdown.impact)} · '
      'recency ${fmt(breakdown.ageBoost)} · '
      'learned ${fmt(breakdown.learnedWeight)}';
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bg, fg) = score >= 75
        ? (colors.errorContainer, colors.error)
        : score >= 50
            ? (colors.tertiaryContainer, colors.onTertiaryContainer)
            : (colors.primaryContainer, colors.primary);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: AksharaRadius.chip),
      child: Text(
        '$score',
        style: context.aksharaText.labelLarge.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
