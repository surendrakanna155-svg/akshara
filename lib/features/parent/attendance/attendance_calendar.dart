import 'package:flutter/material.dart';

import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'attendance_models.dart';

/// PA-02 calendar card with weekday headers, day grid, and legend (358×320+).
class AttendanceCalendar extends StatelessWidget {
  const AttendanceCalendar({
    super.key,
    required this.days,
    required this.onDayTap,
    this.highlightAbsent = false,
    this.cellSize = 48,
  });

  final List<AttendanceCalendarDay> days;
  final void Function(AttendanceCalendarDay day) onDayTap;
  final bool highlightAbsent;
  final double cellSize;

  static const double cardHeight = 360;
  static const List<String> _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final rows = <List<AttendanceCalendarDay>>[];

    for (var i = 0; i < days.length; i += 7) {
      rows.add(days.sublist(i, i + 7 > days.length ? days.length : i + 7));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Column(
          children: [
            SizedBox(
              height: 24,
              child: Row(
                children: [
                  for (final label in _weekdays)
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: text.labelSmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Expanded(
              child: Column(
                children: [
                  for (final row in rows) ...[
                    SizedBox(
                      height: cellSize,
                      child: Row(
                        children: [
                          for (var i = 0; i < 7; i++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: i < 6 ? AksharaSpacing.s1 : AksharaSpacing.s0,
                                ),
                                child: i < row.length
                                    ? _CalendarDayCell(
                                        day: row[i],
                                        size: cellSize,
                                        highlightAbsent: highlightAbsent,
                                        onTap: row[i].isTappable
                                            ? () => onDayTap(row[i])
                                            : null,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (row != rows.last)
                      const SizedBox(height: AksharaSpacing.s1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AksharaSpacing.s2),
            const _AttendanceLegend(),
          ],
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.size,
    required this.highlightAbsent,
    this.onTap,
  });

  final AttendanceCalendarDay day;
  final double size;
  final bool highlightAbsent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (day.isPadding) {
      return SizedBox(width: size, height: size);
    }

    final colors = context.colors;
    final text = context.aksharaText;
    final style = _cellStyle(context, day.status);
    final emphasizeAbsent =
        highlightAbsent && day.status == AttendanceDayStatus.absent;

    return Semantics(
      button: onTap != null,
      label: day.dayNumber != null
          ? 'Day ${day.dayNumber}, ${_statusLabel(day.status)}'
          : null,
      child: Material(
        color: style.background,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.chip,
          side: BorderSide(
            color: day.isSelected
                ? colors.primary
                : emphasizeAbsent
                    ? colors.error
                    : Colors.transparent,
            width: day.isSelected || emphasizeAbsent ? 2 : 0,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AksharaRadius.chip,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Text(
                '${day.dayNumber}',
                style: text.labelMedium.copyWith(
                  color: style.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(AttendanceDayStatus status) {
    return switch (status) {
      AttendanceDayStatus.present => 'present',
      AttendanceDayStatus.absent => 'absent',
      AttendanceDayStatus.late => 'late',
      AttendanceDayStatus.halfDay => 'half-day',
      AttendanceDayStatus.excused => 'excused',
      AttendanceDayStatus.holiday => 'holiday',
      AttendanceDayStatus.future => 'future',
      AttendanceDayStatus.empty => 'empty',
    };
  }

  ({Color background, Color foreground}) _cellStyle(
    BuildContext context,
    AttendanceDayStatus status,
  ) {
    final colors = context.colors;
    final ext = context.akshara;

    return switch (status) {
      AttendanceDayStatus.present => (
          background: ext.successContainer,
          foreground: colors.onSurface,
        ),
      AttendanceDayStatus.absent => (
          background: colors.errorContainer,
          foreground: colors.error,
        ),
      AttendanceDayStatus.late => (
          background: ext.warningContainer,
          foreground: colors.onSurface,
        ),
      AttendanceDayStatus.halfDay => (
          background: ext.indigoContainer,
          foreground: colors.onSurface,
        ),
      AttendanceDayStatus.excused => (
          background: ext.tertiaryContainer,
          foreground: colors.onSurface,
        ),
      AttendanceDayStatus.holiday => (
          background: ext.surfaceContainerHighest,
          foreground: colors.onSurfaceVariant,
        ),
      AttendanceDayStatus.future => (
          background: Colors.transparent,
          foreground: colors.onSurfaceVariant,
        ),
      AttendanceDayStatus.empty => (
          background: Colors.transparent,
          foreground: colors.onSurfaceVariant.withValues(alpha: 0.38),
        ),
    };
  }
}

class _AttendanceLegend extends StatelessWidget {
  const _AttendanceLegend();

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    final ext = context.akshara;

    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(
              label: 'Present',
              dotColor: ext.success,
              textStyle: text.bodySmall,
            ),
            const SizedBox(width: AksharaSpacing.s3),
            _LegendItem(
              label: 'Absent',
              dotColor: colors.error,
              textStyle: text.bodySmall,
            ),
            const SizedBox(width: AksharaSpacing.s3),
            _LegendItem(
              label: 'Late',
              dotColor: ext.warning,
              textStyle: text.bodySmall,
            ),
            const SizedBox(width: AksharaSpacing.s3),
            _LegendItem(
              label: 'Half-day',
              dotColor: ext.indigo,
              textStyle: text.bodySmall,
            ),
            const SizedBox(width: AksharaSpacing.s3),
            _LegendItem(
              label: 'Excused',
              dotColor: ext.tertiary,
              textStyle: text.bodySmall,
            ),
            const SizedBox(width: AksharaSpacing.s3),
            _LegendItem(
              label: 'Holiday',
              dotColor: colors.onSurfaceVariant,
              textStyle: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.dotColor,
    required this.textStyle,
  });

  final String label;
  final Color dotColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AksharaSpacing.s1),
        Text(
          label,
          style: textStyle.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
