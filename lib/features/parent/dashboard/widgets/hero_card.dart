import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/elevation.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../parent_dashboard_provider.dart';

/// PA-01 hero greeting card with status chips (§3 Section/HeroGreeting).
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.schoolName,
    required this.statusChips,
    this.onSchoolLogoTap,
  });

  final String eyebrow;
  final String headline;
  final String schoolName;
  final List<DashboardStatusChip> statusChips;
  final VoidCallback? onSchoolLogoTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: '$eyebrow. $headline',
      child: Card(
        elevation: AksharaElevation.level1,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow,
                          style: text.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AksharaSpacing.s1),
                        Text(
                          headline,
                          style: text.headlineSmall.copyWith(
                            color: colors.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  _SchoolLogo(
                    schoolName: schoolName,
                    onTap: onSchoolLogoTap,
                  ),
                ],
              ),
              if (statusChips.isNotEmpty) ...[
                const SizedBox(height: AksharaSpacing.s3),
                Wrap(
                  spacing: AksharaSpacing.s2,
                  runSpacing: AksharaSpacing.s2,
                  children: [
                    for (final chip in statusChips)
                      AksharaStatusChip(
                        label: chip.label,
                        background: _chipColors(context, chip.tone).$1,
                        foreground: _chipColors(context, chip.tone).$2,
                        size: AksharaStatusChipSize.standard,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color) _chipColors(BuildContext context, DashboardChipTone tone) {
    final colors = context.colors;
    final ext = context.akshara;

    return switch (tone) {
      DashboardChipTone.primary => (
          colors.primaryContainer,
          colors.onPrimaryContainer,
        ),
      DashboardChipTone.success => (
          ext.successContainer,
          ext.success,
        ),
      DashboardChipTone.warning => (
          ext.warningContainer,
          ext.warning,
        ),
      DashboardChipTone.error => (
          colors.errorContainer,
          colors.error,
        ),
    };
  }
}

class _SchoolLogo extends StatelessWidget {
  const _SchoolLogo({
    required this.schoolName,
    this.onTap,
  });

  final String schoolName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: onTap != null,
      label: schoolName,
      child: Material(
        color: colors.primaryContainer,
        borderRadius: AksharaRadius.chip,
        child: InkWell(
          onTap: onTap,
          borderRadius: AksharaRadius.chip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.school_outlined,
              size: 24,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
