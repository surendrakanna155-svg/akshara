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
import '../adaptive_lifecycle.dart';

/// The overflow-menu choices on a feed row (P2-6 audit). Dismiss folds the
/// former standalone icon button in here to keep the dense row compact; Mute
/// records `suppress` (learn not to resurface this item TYPE for the persona).
enum _FeedItemMenuChoice { pin, dismiss, snooze, complete, suppress }

/// Why a previously put-away item is on the list again, in the user's words.
/// Null for an item they have never acted on — the common case, which needs no
/// explanation. Mirrors the `VisibilityReason` values from item_lifecycle.ts.
String? _resurfacedLabel(AdaptivePriorityItem item) => switch (item.visibilityReason) {
      'visible_severity_increased' => 'Back — this got more urgent',
      'visible_deadline_advanced' => 'Back — the deadline is closer',
      'visible_snooze_elapsed' => 'Back — you asked to be reminded',
      _ => null,
    };

class AdaptivePriorityFeedSection extends ConsumerStatefulWidget {
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
  ConsumerState<AdaptivePriorityFeedSection> createState() =>
      _AdaptivePriorityFeedSectionState();
}

class _AdaptivePriorityFeedSectionState
    extends ConsumerState<AdaptivePriorityFeedSection> {
  /// Items the user has just put away, hidden locally until the refetched feed
  /// agrees. Two reasons this must be local and synchronous:
  ///
  ///  1. `Dismissible` asserts the widget leaves the tree in the same frame its
  ///     `onDismissed` fires. Waiting for the network round-trip and provider
  ///     invalidation throws "A dismissed Dismissible widget is still part of
  ///     the tree" — in production, not just in tests.
  ///  2. It is what makes the next item promote instantly. The feed fetches
  ///     more than [maxItems], so removing one reveals the next-highest
  ///     immediately rather than after the server answers.
  final Set<String> _putAway = {};

  String get persona => widget.persona;
  int get maxItems => widget.maxItems;
  String get title => widget.title;
  void Function(BuildContext, AdaptiveAction)? get onOpenAction => widget.onOpenAction;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adaptiveRecommendationsProvider(persona));
    return async.maybeWhen(
      data: (feed) {
        // Once the server stops sending an item, drop it from the local set so
        // it cannot grow without bound across a long-lived dashboard.
        final live = feed.items.map((i) => i.itemKey).toSet();
        _putAway.removeWhere((key) => !live.contains(key));

        final visible = feed.items
            .where((i) => !_putAway.contains(i.itemKey))
            .take(maxItems)
            .toList();
        if (visible.isEmpty) return const SizedBox.shrink();
        return _section(context, ref, visible, feed.degraded);
      },
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
          // Living Dashboard: swipe puts an item away. The card leaves
          // immediately (optimistic) and the next-highest item is promoted by
          // the provider invalidation — the feed already fetches more than it
          // shows, so there is normally something ready to take its place.
          //
          // Swipe does NOT delete the underlying work: this records an
          // `acknowledged` lifecycle row, which is day-scoped and re-surfaces if
          // the item escalates or its deadline advances a band.
          Dismissible(
            key: ValueKey('adaptive-feed-item-${item.itemKey}'),
            // A pinned card cannot be swiped away: the user asked for it to stay
            // in front of them, and a stray swipe undoing that is worse than
            // making them unpin first.
            direction:
                item.pinned ? DismissDirection.none : DismissDirection.endToStart,
            background: _SwipeBackground(colors: context.colors),
            onDismissed: (_) => _runLifecycle(
              context,
              ref,
              persona: persona,
              item: item,
              action: AdaptiveLifecycleAction.acknowledge,
              feedback: AdaptiveFeedbackAction.dismiss,
              failureMessage: 'Could not put that away — it is still on your list.',
            ),
            child: _AdaptiveRecommendationTile(
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
              onDismiss: () => _runLifecycle(
                context,
                ref,
                persona: persona,
                item: item,
                action: AdaptiveLifecycleAction.acknowledge,
                feedback: AdaptiveFeedbackAction.dismiss,
                failureMessage: 'Could not put that away — it is still on your list.',
              ),
              onSnooze: () => _promptSnooze(context, ref, persona: persona, item: item),
              onComplete: () => _runLifecycle(
                context,
                ref,
                persona: persona,
                item: item,
                action: AdaptiveLifecycleAction.complete,
                feedback: AdaptiveFeedbackAction.accept,
                failureMessage: 'Could not mark that done — it is still on your list.',
              ),
              onSuppress: () => recordAdaptiveFeedback(
                ref,
                persona: persona,
                item: item,
                action: AdaptiveFeedbackAction.suppress,
              ),
              onTogglePin: () => _togglePin(context, ref, persona: persona, item: item),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s2),
        ],
      ],
    );
  }

  Future<void> _togglePin(
    BuildContext context,
    WidgetRef ref, {
    required String persona,
    required AdaptivePriorityItem item,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await setAdaptivePinned(ref, persona: persona, item: item, pinned: !item.pinned);
    } catch (_) {
      messenger?.showSnackBar(
        SnackBar(content: Text(item.pinned ? "Couldn't unpin that." : "Couldn't pin that.")),
      );
    }
  }

  /// Ask which snooze window, then record it. Returns without writing if the
  /// user backs out of the sheet.
  Future<void> _promptSnooze(
    BuildContext context,
    WidgetRef ref, {
    required String persona,
    required AdaptivePriorityItem item,
  }) async {
    final option = await showModalBottomSheet<AdaptiveSnoozeOption>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in AdaptiveSnoozeOption.values)
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(option.label),
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (option == null) return;
    if (!context.mounted) return;
    await _runLifecycle(
      context,
      ref,
      persona: persona,
      item: item,
      action: AdaptiveLifecycleAction.snooze,
      // No learning signal: "not now" is not "this was a bad suggestion", so
      // snoozing must never down-weight the whole item type.
      feedback: null,
      snoozedUntil: resolveSnoozeUntil(option, DateTime.now()),
      failureMessage: 'Could not snooze that — it is still on your list.',
    );
  }

  /// Record a lifecycle change, surfacing failure instead of swallowing it.
  ///
  /// The card has already left the screen by the time this runs, so a silent
  /// failure would leave the user believing an item is put away when the server
  /// never recorded it — and it would reappear later with no explanation. On
  /// failure we say so and invalidate, which restores the true server state.
  Future<void> _runLifecycle(
    BuildContext context,
    WidgetRef ref, {
    required String persona,
    required AdaptivePriorityItem item,
    required AdaptiveLifecycleAction action,
    required String failureMessage,
    AdaptiveFeedbackAction? feedback,
    DateTime? snoozedUntil,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Hide it in THIS frame — Dismissible requires it, and it is what makes the
    // next item appear instantly rather than after the server answers.
    setState(() => _putAway.add(item.itemKey));
    try {
      await recordAdaptiveLifecycle(
        ref,
        persona: persona,
        item: item,
        action: action,
        snoozedUntil: snoozedUntil,
        feedback: feedback,
      );
    } catch (_) {
      // The write never landed, so put it back rather than leaving the user
      // believing it was handled. Saying so matters more than the visual jump:
      // a silently-returning item later reads as the app ignoring them.
      if (mounted) setState(() => _putAway.remove(item.itemKey));
      messenger?.showSnackBar(SnackBar(content: Text(failureMessage)));
      ref.invalidate(adaptiveRecommendationsProvider(persona));
      ref.invalidate(adaptivePriorityFeedProvider(persona));
    }
  }
}

/// The reveal behind a swiped card. Reads as "putting away", not "deleting" —
/// the work is not destroyed, it is just off today's list.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AksharaRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: AksharaSpacing.s2),
          Text(
            'Put away',
            style: context.aksharaText.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveRecommendationTile extends StatefulWidget {
  const _AdaptiveRecommendationTile({
    required this.item,
    required this.onOpen,
    required this.onDismiss,
    required this.onSnooze,
    required this.onComplete,
    required this.onSuppress,
    required this.onTogglePin,
  });

  final AdaptivePriorityItem item;
  final VoidCallback? onOpen;
  final VoidCallback onDismiss;
  final VoidCallback onSnooze;
  final VoidCallback onComplete;
  final VoidCallback onSuppress;
  final VoidCallback onTogglePin;

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
                    Row(
                      children: [
                        if (item.pinned) ...[
                          Icon(Icons.push_pin, size: 13, color: colors.primary),
                          const SizedBox(width: AksharaSpacing.s1),
                        ],
                        Expanded(
                          child: Text(item.title, style: context.aksharaText.bodyMedium),
                        ),
                      ],
                    ),
                    // An item the user already put away does not reappear
                    // silently — say why it is back, or it reads as the app
                    // ignoring their dismissal.
                    if (_resurfacedLabel(item) != null) ...[
                      const SizedBox(height: AksharaSpacing.s1),
                      Text(
                        _resurfacedLabel(item)!,
                        style: context.aksharaText.labelSmall.copyWith(color: colors.error),
                      ),
                    ],
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
                    case _FeedItemMenuChoice.pin:
                      widget.onTogglePin();
                    case _FeedItemMenuChoice.dismiss:
                      widget.onDismiss();
                    case _FeedItemMenuChoice.snooze:
                      widget.onSnooze();
                    case _FeedItemMenuChoice.complete:
                      widget.onComplete();
                    case _FeedItemMenuChoice.suppress:
                      widget.onSuppress();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _FeedItemMenuChoice.pin,
                    child: Text(item.pinned ? 'Unpin' : 'Pin to top'),
                  ),
                  const PopupMenuItem(
                    value: _FeedItemMenuChoice.dismiss,
                    child: Text('Put away for today'),
                  ),
                  const PopupMenuItem(
                    value: _FeedItemMenuChoice.snooze,
                    child: Text('Remind me later'),
                  ),
                  const PopupMenuItem(
                    value: _FeedItemMenuChoice.complete,
                    child: Text('Mark done'),
                  ),
                  const PopupMenuItem(
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
                  // Flexible + ellipsis: a long action label ("Open recovery
                  // call queue") must shrink at narrow widths instead of
                  // overflowing the row (caught by router_smoke_test).
                  Flexible(
                    child: TextButton(
                      onPressed: widget.onOpen,
                      child: Text(
                        item.action!.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
