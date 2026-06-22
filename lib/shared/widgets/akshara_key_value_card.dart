import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Stacked-card fallback for a single data-table row on phones / portrait
/// tablets (the B.4e table→card sweep).
///
/// Renders a hairline-bordered card with a leading title (a plain [title]
/// string or a custom [titleWidget] such as a status chip), an optional
/// [trailing] widget on the title row (e.g. a row action button), then one
/// `label · value` line per entry. Pairs are `(label, value)` records.
class AksharaKeyValueCard extends StatelessWidget {
  const AksharaKeyValueCard({
    super.key,
    this.title,
    this.titleWidget,
    required this.entries,
    this.trailing,
  }) : assert(title != null || titleWidget != null,
            'Provide either title or titleWidget');

  /// Plain-text title (rendered as `titleSmall`). Ignored if [titleWidget] set.
  final String? title;

  /// Custom title widget (e.g. a status chip), overrides [title].
  final Widget? titleWidget;

  /// `(label, value)` pairs shown one per line under the title.
  final List<(String, String)> entries;

  /// Optional trailing widget on the title row (e.g. an action button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: titleWidget ?? Text(title!, style: text.titleSmall),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AksharaSpacing.s2),
                  trailing!,
                ],
              ],
            ),
            for (final (label, value) in entries)
              Padding(
                padding: const EdgeInsets.only(top: AksharaSpacing.s1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: text.bodySmall
                          .copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(width: AksharaSpacing.s3),
                    Flexible(
                      child: Text(
                        value,
                        style: text.bodySmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
