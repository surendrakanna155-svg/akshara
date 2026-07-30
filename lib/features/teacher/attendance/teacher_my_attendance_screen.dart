import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/premium_tokens.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'my_attendance_models.dart';
import 'my_attendance_provider.dart';

/// TCH-9 — a teacher's OWN staff attendance history (READ-ONLY). Shows Today /
/// Yesterday cards, month summary chips, a per-day list, and a month switcher.
/// No mutation: correction requests live on the class-attendance surface.
class TeacherMyAttendanceScreen extends ConsumerWidget {
  const TeacherMyAttendanceScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(myAttendanceMonthProvider);
    final async = ref.watch(myAttendanceHistoryProvider(month));

    return Scaffold(
      key: QaTestKeys.teacherMyAttendanceScreen,
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: 'My Attendance',
        subtitle: 'Your own check-in history',
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      // DS V2 P4 — premium persona canvas behind the self-history.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: async.when(
          loading: () =>
              const AksharaLoadingState(semanticLabel: 'Loading my attendance'),
          error: (_, __) => AksharaErrorState(
            message: 'Unable to load your attendance history.',
            onRetry: () => ref.invalidate(myAttendanceHistoryProvider(month)),
          ),
          data: (history) => _MyAttendanceBody(history: history),
        ),
      ),
    );
  }
}

class _MyAttendanceBody extends ConsumerWidget {
  const _MyAttendanceBody({required this.history});

  final MyAttendanceHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = history.summary;
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        _MonthSwitcher(month: history.month),
        const SizedBox(height: AksharaSpacing.s4),
        // DS V2 P4 — signature monthly attendance-rate ring (present + late over
        // working days). The count chips below carry the raw breakdown.
        _MonthAttendanceRingCard(summary: summary),
        const SizedBox(height: AksharaSpacing.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TodayCard(title: 'Today', day: history.today),
            ),
            const SizedBox(width: AksharaSpacing.s3),
            Expanded(
              child: _TodayCard(title: 'Yesterday', day: history.yesterday),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s4),
        const AksharaSectionHeader(
          title: 'This month',
          fixedHeight: false,
          spacingBelow: AksharaSpacing.s3,
        ),
        _SummaryChips(summary: summary),
        const SizedBox(height: AksharaSpacing.s4),
        const AksharaSectionHeader(
          title: 'Days',
          fixedHeight: false,
          spacingBelow: AksharaSpacing.s3,
        ),
        if (history.days.isEmpty)
          const AksharaSectionEmpty(
            message: 'No attendance recorded for this month yet.',
            icon: Icons.event_busy_outlined,
          )
        else
          for (final day in history.days.reversed) ...[
            _DayRow(day: day),
            const SizedBox(height: AksharaSpacing.s2),
          ],
      ],
    );
  }
}

/// DS V2 P4 — the month's attendance rate as a signature persona-accent
/// progress **ring** (attended = present + late, over working days). Honest:
/// derived only from data already loaded; contextualises the count chips below.
class _MonthAttendanceRingCard extends StatelessWidget {
  const _MonthAttendanceRingCard({required this.summary});

  final MyAttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final premium = context.premium;
    final text = context.aksharaText;
    final colors = context.colors;

    final attended = summary.presentDays + summary.lateDays;
    final working = summary.workingDaysInMonth;
    final rate = working > 0 ? attended / working : 0.0;
    final percent = (rate * 100).round();

    return Semantics(
      container: true,
      label: 'Attendance $percent percent this month, '
          '$attended of $working working days attended',
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
                value: rate,
                size: 92,
                strokeWidth: 9,
                color: premium.brandStart,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: text.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'Attendance',
                      style: text.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
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
                    Text(
                      'This month',
                      style: text.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      'Present on $attended of $working working days',
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
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
}

class _MonthSwitcher extends ConsumerWidget {
  const _MonthSwitcher({required this.month});

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    return Row(
      children: [
        IconButton(
          key: QaTestKeys.teacherMyAttendancePrevMonthButton,
          tooltip: 'Previous month',
          onPressed: () => ref.read(myAttendanceMonthProvider.notifier).state =
              _shiftMonth(month, -1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            _monthLabel(month),
            textAlign: TextAlign.center,
            style: text.titleMedium,
          ),
        ),
        IconButton(
          key: QaTestKeys.teacherMyAttendanceNextMonthButton,
          tooltip: 'Next month',
          onPressed: _isCurrentOrFuture(month)
              ? null
              : () => ref.read(myAttendanceMonthProvider.notifier).state =
                  _shiftMonth(month, 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.title, required this.day});

  final String title;
  final MyAttendanceDay? day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final resolved = day;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AksharaRadius.card,
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: text.labelMedium
                    .copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: AksharaSpacing.s2),
            if (resolved == null)
              Text('No record',
                  style: text.bodyMedium
                      .copyWith(color: colors.onSurfaceVariant))
            else ...[
              _StatusChipFor(status: resolved.status, isLate: resolved.isLate),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                _inOutLabel(resolved),
                style: text.bodySmall
                    .copyWith(color: colors.onSurfaceVariant),
              ),
              if (resolved.workingHoursLabel != null) ...[
                const SizedBox(height: 2),
                Text('Worked ${resolved.workingHoursLabel}',
                    style: text.bodySmall
                        .copyWith(color: colors.onSurfaceVariant)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({required this.summary});

  final MyAttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AksharaKpiCard(
              value: '${summary.presentDays}',
              subtitle: 'Present',
              accent: KpiAccent.success,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${summary.lateDays}',
              subtitle: 'Late',
              accent: KpiAccent.warning,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${summary.absentDays}',
              subtitle: 'Absent',
              accent: KpiAccent.error,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: summary.avgWorkingHoursLabel,
              subtitle: 'Avg hours',
              accent: KpiAccent.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});

  final MyAttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    return Material(
      key: QaTestKeys.teacherMyAttendanceDayRow(day.date),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AksharaRadius.card,
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AksharaSpacing.s3,
          vertical: AksharaSpacing.s2,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                _dayLabel(day.date),
                style: text.titleSmall,
              ),
            ),
            const SizedBox(width: AksharaSpacing.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _inOutLabel(day),
                    style: text.bodyMedium,
                  ),
                  if (day.workingHoursLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Worked ${day.workingHoursLabel}',
                      style: text.bodySmall
                          .copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (day.manualOverride) ...[
              const Tooltip(
                message: 'Manual override applied',
                child: Icon(Icons.edit_calendar_outlined, size: 18),
              ),
              const SizedBox(width: AksharaSpacing.s2),
            ],
            _StatusChipFor(status: day.status, isLate: day.isLate),
          ],
        ),
      ),
    );
  }
}

class _StatusChipFor extends StatelessWidget {
  const _StatusChipFor({required this.status, required this.isLate});

  final MyAttendanceStatus status;
  final bool isLate;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      MyAttendanceStatus.present => KpiAccent.success,
      MyAttendanceStatus.late => KpiAccent.warning,
      MyAttendanceStatus.absent => KpiAccent.error,
      MyAttendanceStatus.holiday => KpiAccent.neutral,
    };
    return AksharaStatusChip(label: status.label, tone: tone);
  }
}

// --- helpers ---------------------------------------------------------------

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Human month label from a `YYYY-MM` string. Falls back to the current month
/// when the string is empty (the "current month" default the backend resolves).
String _monthLabel(String month) {
  final parsed = _parse(month);
  return '${_monthNames[parsed.month - 1]} ${parsed.year}';
}

String _dayLabel(String isoDate) {
  final parts = isoDate.split('-');
  if (parts.length < 3) return isoDate;
  return parts[2];
}

String _inOutLabel(MyAttendanceDay day) {
  final inLabel = _timeLabel(day.checkIn);
  final outLabel = _timeLabel(day.checkOut);
  if (inLabel == null && outLabel == null) {
    return day.status == MyAttendanceStatus.holiday ? 'Holiday' : 'No check-in';
  }
  return 'In ${inLabel ?? '—'} · Out ${outLabel ?? '—'}';
}

String? _timeLabel(String? iso) {
  if (iso == null) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  final local = dt.toLocal();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  return '$h:${local.minute.toString().padLeft(2, '0')} $ampm';
}

({int year, int month}) _parse(String month) {
  final now = DateTime.now();
  if (month.isEmpty) return (year: now.year, month: now.month);
  final parts = month.split('-');
  final y = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? now.year;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? now.month;
  return (year: y, month: m);
}

/// Shifts a `YYYY-MM` (or empty = current) by [delta] months.
String _shiftMonth(String month, int delta) {
  final parsed = _parse(month);
  final shifted = DateTime(parsed.year, parsed.month + delta, 1);
  return '${shifted.year.toString().padLeft(4, '0')}-'
      '${shifted.month.toString().padLeft(2, '0')}';
}

bool _isCurrentOrFuture(String month) {
  final parsed = _parse(month);
  final now = DateTime.now();
  final shown = DateTime(parsed.year, parsed.month);
  final current = DateTime(now.year, now.month);
  return !shown.isBefore(current);
}
