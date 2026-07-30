import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/premium_tokens.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../../theme/typography.dart';
import '../teacher_dashboard_provider.dart';

/// TA-01 attendance summary — staff check-in, warning banner, KPI strip.
class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({
    super.key,
    required this.checkIn,
    required this.summary,
    this.onCheckInTap,
    this.onCheckInNowTap,
    this.onMarkAttendanceTap,
  });

  final StaffCheckInInfo checkIn;
  final AttendanceSummary summary;
  final VoidCallback? onCheckInTap;
  final VoidCallback? onCheckInNowTap;
  final VoidCallback? onMarkAttendanceTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StaffCheckInCard(
          checkIn: checkIn,
          onViewTap: onCheckInTap,
          onCheckInNowTap: onCheckInNowTap,
        ),
        if (summary.hasPendingAttendance) ...[
          const SizedBox(height: AksharaSpacing.s4),
          AksharaWarningBanner(
            message: summary.pendingBannerMessage!,
            actionLabel: summary.pendingBannerActionLabel,
            onAction: onMarkAttendanceTap,
            borderRadius: AksharaRadius.card,
            compactMessage: true,
            horizontalPaddingOnly: true,
            alwaysShowAction: true,
            semanticLabel: 'Warning: ${summary.pendingBannerMessage}',
          ),
        ],
        const SizedBox(height: AksharaSpacing.s4),
        _AttendanceKpiStrip(summary: summary),
      ],
    );
  }
}

class _StaffCheckInCard extends StatelessWidget {
  const _StaffCheckInCard({
    required this.checkIn,
    this.onViewTap,
    this.onCheckInNowTap,
  });

  final StaffCheckInInfo checkIn;
  final VoidCallback? onViewTap;
  final VoidCallback? onCheckInNowTap;

  static const double cardHeight = 88;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ext = context.akshara;
    final text = context.aksharaText;
    final isCheckedIn = checkIn.status == StaffCheckInStatus.checkedIn;

    return Semantics(
      container: true,
      label: isCheckedIn
          ? 'Checked in at ${checkIn.checkedInAt}'
          : 'Not checked in',
      child: Material(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: cardHeight),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCheckedIn
                        ? ext.successContainer
                        : ext.warningContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCheckedIn
                        ? Icons.check_circle_outline
                        : Icons.login_outlined,
                    size: 24,
                    color: isCheckedIn ? ext.success : ext.warning,
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isCheckedIn ? 'Checked in' : 'Not checked in',
                        style: text.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isCheckedIn &&
                          checkIn.checkedInAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${checkIn.checkedInAt} · ${checkIn.verificationLabel ?? ''}',
                          style: text.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        const SizedBox(height: 2),
                        Text(
                          'Tap to check in for today',
                          style: text.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isCheckedIn)
                  TextButton(
                    onPressed: onViewTap,
                    child: const Text('View'),
                  )
                else
                  FilledButton(
                    onPressed: onCheckInNowTap,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AksharaSpacing.s4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AksharaRadius.button,
                      ),
                    ),
                    child: const Text('Check in now'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// DS V2 Phase 3 flagship — the class-attendance summary led by a signature
/// present-rate progress **ring** in the persona accent, with the classes-marked
/// and students-present counts as adjacent stats. Presentation only; conveys the
/// same three metrics as the old three-up KPI strip.
class _AttendanceKpiStrip extends StatelessWidget {
  const _AttendanceKpiStrip({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final presentRate = summary.studentsTotal == 0
        ? 0
        : ((summary.studentsPresent / summary.studentsTotal) * 100).round();
    final premium = context.premium;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label:
          'Attendance summary: ${summary.classesMarked} of ${summary.classesTotal} classes marked, '
          '$presentRate percent students present',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: premium.premiumSurface,
          borderRadius: BorderRadius.circular(AksharaRadius.xl),
          border: Border.all(color: premium.premiumBorder),
          boxShadow: premium.softShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AksharaProgressRing(
                value: presentRate / 100.0,
                size: 92,
                strokeWidth: 9,
                color: premium.brandStart,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$presentRate%',
                      style: text.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'Present',
                      style: text.labelSmall.copyWith(
                        color: context.colors.onSurfaceVariant,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AksharaSpacing.s5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stat(
                      context,
                      'Classes marked',
                      '${summary.classesMarked}/${summary.classesTotal}',
                    ),
                    const SizedBox(height: AksharaSpacing.s3),
                    _stat(
                      context,
                      'Students present',
                      '${summary.studentsPresent}/${summary.studentsTotal}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: text.titleLarge.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.05,
          ).tabularFigures,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
