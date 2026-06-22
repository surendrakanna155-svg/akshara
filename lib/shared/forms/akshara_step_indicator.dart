import 'package:flutter/material.dart';

import '../../theme/breakpoints.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Shared wizard step indicator for any multi-step form.
///
/// Generalized from the admissions enrollment indicator (B.4d) so every
/// wizard can share one look. Responsive:
/// * **Tablet / desktop** — the full row of numbered circles + connectors +
///   labels (the original admissions look).
/// * **Phone** — a compact `Step N of M` eyebrow + the current step label +
///   a thin progress bar. The full labelled-circle row is too cramped at
///   ~358px, so phones get the premium compact form instead.
class AksharaStepIndicator extends StatelessWidget {
  const AksharaStepIndicator({
    super.key,
    required this.stepLabels,
    required this.currentIndex,
  }) : assert(stepLabels.length > 0, 'stepLabels must not be empty');

  /// Ordered labels, one per step.
  final List<String> stepLabels;

  /// Zero-based index of the active step.
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final clampedIndex = currentIndex.clamp(0, stepLabels.length - 1);
    final isMobile =
        AksharaBreakpoints.isMobile(MediaQuery.sizeOf(context).width);

    return Semantics(
      container: true,
      label:
          'Step ${clampedIndex + 1} of ${stepLabels.length}: ${stepLabels[clampedIndex]}',
      child: isMobile
          ? _CompactIndicator(
              stepLabels: stepLabels,
              currentIndex: clampedIndex,
            )
          : _FullIndicator(
              stepLabels: stepLabels,
              currentIndex: clampedIndex,
            ),
    );
  }
}

/// Phone form: `Step N of M` eyebrow + current label + progress bar.
class _CompactIndicator extends StatelessWidget {
  const _CompactIndicator({
    required this.stepLabels,
    required this.currentIndex,
  });

  final List<String> stepLabels;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final total = stepLabels.length;
    final progress = (currentIndex + 1) / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step ${currentIndex + 1} of $total',
              style: text.labelSmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (currentIndex < total - 1)
              Flexible(
                child: Text(
                  'Next: ${stepLabels[currentIndex + 1]}',
                  style: text.labelSmall
                      .copyWith(color: colors.onSurfaceVariant),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s1),
        Text(
          stepLabels[currentIndex],
          style: text.titleMedium.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AksharaSpacing.s2),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: colors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
      ],
    );
  }
}

/// Tablet / desktop form: numbered circles + connectors + labels.
class _FullIndicator extends StatelessWidget {
  const _FullIndicator({
    required this.stepLabels,
    required this.currentIndex,
  });

  final List<String> stepLabels;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Row(
      children: [
        for (var i = 0; i < stepLabels.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i <= currentIndex
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                      ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: i <= currentIndex
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      child: Text(
                        '${i + 1}',
                        style: text.labelSmall.copyWith(
                          color: i <= currentIndex
                              ? colors.onPrimary
                              : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (i < stepLabels.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i < currentIndex
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  stepLabels[i],
                  style: text.labelSmall.copyWith(
                    color: i == currentIndex
                        ? colors.primary
                        : colors.onSurfaceVariant,
                    fontWeight:
                        i == currentIndex ? FontWeight.w600 : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
