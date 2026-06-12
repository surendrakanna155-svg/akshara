import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Standard elevated surface card for dashboards and list rows.
class AksharaSurfaceCard extends StatelessWidget {
  const AksharaSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AksharaSpacing.s4),
    this.margin,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = Material(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AksharaRadius.card,
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AksharaRadius.card,
        child: Padding(padding: padding, child: child),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: margin == null ? card : Padding(padding: margin!, child: card),
    );
  }
}

/// List-row style surface card with leading icon, title, subtitle, chevron.
class AksharaSurfaceListTile extends StatelessWidget {
  const AksharaSurfaceListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AksharaSurfaceCard(
      onTap: onTap,
      semanticLabel: semanticLabel ?? title,
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: colors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
      ),
    );
  }
}
