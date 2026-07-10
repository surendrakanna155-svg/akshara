// Adaptive AI (P3-AI-2 / W2) — the reusable per-persona priority/recommendation
// feed section. Backend-driven, deterministic (zero-token), explainable (every
// item shows its "why"). SELF-HIDING: renders nothing while loading, on error,
// or when the persona has no feed yet — so it never breaks a home screen and the
// deterministic content below it always shows. The pre-staged action opens a
// screen for the human to act on — AI never executes (governance rail).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../adaptive_ai_models.dart';
import '../adaptive_ai_providers.dart';

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
          : _section(context, ref, feed.items.take(maxItems).toList()),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _section(BuildContext context, WidgetRef ref, List<AdaptivePriorityItem> items) {
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
        const SizedBox(height: AksharaSpacing.s2),
        for (final item in items) ...[
          _AdaptiveRecommendationTile(
            item: item,
            onOpen: onOpenAction == null || item.action == null
                ? null
                : () => onOpenAction!(context, item.action!),
            onDismiss: () => recordAdaptiveFeedback(
              ref,
              persona: persona,
              item: item,
              action: AdaptiveFeedbackAction.dismiss,
            ),
          ),
          const SizedBox(height: AksharaSpacing.s2),
        ],
      ],
    );
  }
}

class _AdaptiveRecommendationTile extends StatelessWidget {
  const _AdaptiveRecommendationTile({
    required this.item,
    required this.onOpen,
    required this.onDismiss,
  });

  final AdaptivePriorityItem item;
  final VoidCallback? onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Dismiss',
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s1),
          Row(
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
              if (onOpen != null && item.action != null)
                TextButton(
                  onPressed: onOpen,
                  child: Text(item.action!.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
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
