import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
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

class _AttendanceKpiStrip extends StatelessWidget {
  const _AttendanceKpiStrip({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final presentRate = summary.studentsTotal == 0
        ? 0
        : ((summary.studentsPresent / summary.studentsTotal) * 100).round();

    return Semantics(
      container: true,
      label:
          'Attendance summary: ${summary.classesMarked} of ${summary.classesTotal} classes marked, '
          '$presentRate percent students present',
      child: Row(
        children: [
          Expanded(
            child: AksharaKpiCard(
              style: AksharaKpiCardStyle.filled,
              value: '${summary.classesMarked}/${summary.classesTotal}',
              subtitle: 'Classes marked',
              accent: KpiAccent.primary,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: AksharaKpiCard(
              style: AksharaKpiCardStyle.filled,
              value: '${summary.studentsPresent}/${summary.studentsTotal}',
              subtitle: 'Students present',
              accent: KpiAccent.success,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: AksharaKpiCard(
              style: AksharaKpiCardStyle.filled,
              value: '$presentRate%',
              subtitle: 'Present rate',
              accent: KpiAccent.neutral,
            ),
          ),
        ],
      ),
    );
  }
}
