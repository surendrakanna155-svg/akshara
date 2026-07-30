// Adaptive AI (P3-AI-2 / W2.S) — Universal Search results section. Deterministic,
// zero-token, RBAC-scoped (the backend only returns what the caller may see).
// Grouped by category (decision 5); each result navigates to the ERP record
// (decision 8) — Search First → AI Later. Self-hides for short/empty queries.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../adaptive_ai_models.dart';
import '../adaptive_ai_providers.dart';

class AdaptiveSearchResults extends ConsumerWidget {
  const AdaptiveSearchResults({
    super.key,
    required this.query,
    required this.onSelect,
  });

  final String query;

  /// Invoked when a record is tapped; the host closes the overlay + navigates.
  final void Function(SearchResultItem result) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().length < 2) return const SizedBox.shrink();
    final async = ref.watch(adaptiveSearchProvider(query));
    final extra = ref.watch(adaptiveSearchExtraProvider(query));
    return async.maybeWhen(
      data: (result) => result.isEmpty ? const SizedBox.shrink() : _groups(context, ref, result, extra),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _groups(
    BuildContext context,
    WidgetRef ref,
    UniversalSearchResult result,
    AdaptiveSearchExtraState extra,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in result.groups) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
            child: Text(
              '${group.label} (${group.total})',
              style: context.aksharaText.labelMedium
                  .copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          for (final item in group.results)
            AksharaSurfaceListTile(
              icon: _iconFor(item.category),
              title: item.title,
              subtitle: item.subtitle,
              onTap: () => onSelect(item),
            ),
          for (final item in extra.extra[group.category] ?? const <SearchResultItem>[])
            AksharaSurfaceListTile(
              icon: _iconFor(item.category),
              title: item.title,
              subtitle: item.subtitle,
              onTap: () => onSelect(item),
            ),
          if (_hasMore(group, extra)) _showMoreButton(context, ref, group, extra),
          const SizedBox(height: AksharaSpacing.s2),
        ],
      ],
    );
  }

  /// How many of [group]'s category have been loaded so far — the base page
  /// plus every accumulated "Show more" page — and therefore the offset the
  /// NEXT page should start at.
  int _loadedCount(SearchGroup group, AdaptiveSearchExtraState extra) =>
      group.offset + group.results.length + (extra.extra[group.category]?.length ?? 0);

  bool _hasMore(SearchGroup group, AdaptiveSearchExtraState extra) =>
      _loadedCount(group, extra) < group.total;

  Widget _showMoreButton(
    BuildContext context,
    WidgetRef ref,
    SearchGroup group,
    AdaptiveSearchExtraState extra,
  ) {
    final isLoading = extra.loadingCategory == group.category;
    return Padding(
      padding: const EdgeInsets.only(left: AksharaSpacing.s1),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: isLoading
            ? null
            : () => ref.read(adaptiveSearchExtraProvider(query).notifier).loadMore(
                  category: group.category,
                  nextOffset: _loadedCount(group, extra),
                ),
        child: Text(isLoading ? 'Loading…' : 'Show more'),
      ),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'students':
        return Icons.school_outlined;
      case 'staff':
        return Icons.badge_outlined;
      case 'admissions':
        return Icons.how_to_reg_outlined;
      case 'finance':
        return Icons.receipt_long_outlined;
      case 'communications':
        return Icons.campaign_outlined;
      case 'classes':
        return Icons.groups_outlined;
      default:
        return Icons.search;
    }
  }
}
