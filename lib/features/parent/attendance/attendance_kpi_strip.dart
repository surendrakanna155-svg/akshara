import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_kpi_card.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'attendance_models.dart';

/// PA-02 KPI summary row — 3× compact cards (358×88).
class AttendanceKpiStrip extends StatelessWidget {
  const AttendanceKpiStrip({
    super.key,
    required this.metrics,
    this.onAbsentTap,
  });

  final AttendanceKpiMetrics metrics;
  final VoidCallback? onAbsentTap;

  static const double height = 88;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: AksharaKpiCard(
              value: '${metrics.attendancePercent}%',
              subtitle: 'This month',
              accent: KpiAccent.success,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${metrics.absentDays}',
              subtitle: 'Absent days',
              accent: KpiAccent.error,
              onTap: onAbsentTap,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${metrics.lateDays}',
              subtitle: 'Late',
              accent: KpiAccent.warning,
            ),
          ),
        ],
      ),
    );
  }
}
