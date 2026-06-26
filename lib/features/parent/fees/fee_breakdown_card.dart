import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'fees_provider.dart';

/// PA-03 fee breakdown accordion (Tuition · Transport · Activity).
class FeeBreakdownCard extends ConsumerWidget {
  const FeeBreakdownCard({
    super.key,
    required this.categories,
  });

  final List<FeeBreakdownCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedIndex = ref.watch(feesAccordionExpandedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(
          title: 'Fee breakdown',
          fixedHeight: false,
          spacingBelow: AksharaSpacing.s2,
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < categories.length; i++)
                _BreakdownPanel(
                  category: categories[i],
                  isExpanded: expandedIndex == i,
                  isLast: i == categories.length - 1,
                  onTap: () {
                    ref.read(feesAccordionExpandedProvider.notifier).state =
                        expandedIndex == i ? null : i;
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BreakdownPanel extends StatelessWidget {
  const _BreakdownPanel({
    required this.category,
    required this.isExpanded,
    required this.isLast,
    required this.onTap,
  });

  final FeeBreakdownCategory category;
  final bool isExpanded;
  final bool isLast;
  final VoidCallback onTap;

  static const double headerHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final categoryTotal = category.lines.fold<int>(
      0,
      (sum, line) => sum + line.amount,
    );

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AksharaSpacing.s4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.title,
                      style: text.bodyLarge.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    formatInr(categoryTotal),
                    style: text.titleSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s2),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AksharaSpacing.s4,
              AksharaSpacing.s0,
              AksharaSpacing.s4,
              AksharaSpacing.s4,
            ),
            child: Column(
              children: [
                for (final line in category.lines)
                  SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            line.label,
                            style: text.bodyMedium.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          formatInr(line.amount),
                          style: text.bodyMedium.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: colors.outlineVariant,
          ),
      ],
    );
  }
}
