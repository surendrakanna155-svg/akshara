import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'akshara_empty_illustration.dart';
import 'akshara_glass_surface.dart';

/// Premium chart container — executive dashboard card shell.
class AksharaChartCard extends StatelessWidget {
  const AksharaChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.legend,
    this.height,
    this.expandBody = false,
    this.semanticLabel,
    this.emptyState,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? legend;
  final double? height;

  /// When true, [child] expands in remaining vertical space (parent must bound height).
  final bool expandBody;
  final String? semanticLabel;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    final sectionGap = expandBody ? AksharaSpacing.s2 : AksharaSpacing.s4;

    final body = emptyState != null
        ? emptyState!
        : expandBody
            ? Expanded(child: child)
            : height == null
                ? child
                : SizedBox(height: height, child: child);

    return Semantics(
      container: true,
      label: semanticLabel ?? title,
      child: AksharaGlassSurface(
        borderRadius: AksharaRadius.cardBorder,
        padding: const EdgeInsets.all(AksharaSpacing.kpiCardPadding),
        showSheen: true,
        enableBlur: false,
        shadowLevel: 1,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: text.titleSmall.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  subtitle!,
                  style: text.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              SizedBox(height: sectionGap),
              body,
              if (legend != null) ...[
                SizedBox(height: sectionGap),
                legend!,
              ],
            ],
        ),
      ),
    );
  }
}

/// Single legend entry for analytics charts.
class AksharaChartLegendItem {
  const AksharaChartLegendItem({
    required this.color,
    required this.label,
    this.value,
  });

  final Color color;
  final String label;
  final String? value;
}

/// Executive legend row for bar, line, and distribution charts.
class AksharaChartLegend extends StatelessWidget {
  const AksharaChartLegend({
    super.key,
    required this.items,
  });

  final List<AksharaChartLegendItem> items;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Wrap(
      spacing: AksharaSpacing.s3,
      runSpacing: AksharaSpacing.s2,
      children: [
        for (final item in items)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s2,
              vertical: items.length > 3 ? 0 : AksharaSpacing.s1,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AksharaRadius.xs),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s2),
                Text(
                  item.value == null
                      ? item.label
                      : '${item.label} · ${item.value}',
                  style: text.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
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

/// Premium empty state for chart panels and analytics zones.
class AksharaChartEmpty extends StatelessWidget {
  const AksharaChartEmpty({
    super.key,
    required this.message,
    this.title = 'No data yet',
    this.icon = Icons.insert_chart_outlined,
    this.actionLabel,
    this.onAction,
    this.height = 200,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: AksharaEmptyContent(
          compact: true,
          title: title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          illustration: AksharaEmptyIllustration(
            icon: icon,
            tone: AksharaEmptyTone.info,
            size: AksharaEmptyIllustrationSize.standard,
          ),
        ),
      ),
    );
  }
}

/// Subtle horizontal guides behind bar charts.
class AksharaChartGridPainter extends CustomPainter {
  AksharaChartGridPainter({required this.lineColor, this.lineCount = 4});

  final Color lineColor;
  final int lineCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    for (var i = 1; i <= lineCount; i++) {
      final y = size.height * (i / (lineCount + 1));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant AksharaChartGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.lineCount != lineCount;
}

/// Shared legend dot — prefer [AksharaChartLegend] for new charts.
class AksharaChartLegendDot extends StatelessWidget {
  const AksharaChartLegendDot({
    super.key,
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AksharaChartLegend(
      items: [AksharaChartLegendItem(color: color, label: label)],
    );
  }
}
