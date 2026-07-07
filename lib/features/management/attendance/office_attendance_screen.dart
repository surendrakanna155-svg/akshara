import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/attendance/attendance_office_models.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_freshness_chip.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';

// --- Office attendance filter state (class + date + month) -------------------

/// The class label the register/monthly tabs are viewing.
final officeAttendanceClassProvider = StateProvider<String>((ref) => '8-A');

/// The date the register + pending tabs are viewing.
final officeAttendanceDateProvider =
    StateProvider<DateTime>((ref) => _today());

/// The month (YYYY-MM) the monthly tab is viewing.
final officeAttendanceMonthProvider = StateProvider<String>((ref) {
  final now = _today();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}';
});

/// The short-attendance threshold percent (ATT-D2, default 75).
final officeShortAttendanceThresholdProvider = StateProvider<int>((ref) => 75);

/// The consecutive-absence window in days (ATT-D1, default 3).
final officeConsecutiveDaysProvider = StateProvider<int>((ref) => 3);

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

// --- Data providers ----------------------------------------------------------

final officeRegisterProvider =
    FutureProvider.autoDispose<List<AttendanceRegisterEntry>>((ref) async {
  final classLabel = ref.watch(officeAttendanceClassProvider);
  final date = ref.watch(officeAttendanceDateProvider);
  return ref.read(attendanceOfficeRepositoryProvider).fetchRegister(
        query: ref.watch(repositoryQueryProvider),
        classLabel: classLabel,
        date: date,
      );
});

final officeMonthlyRegisterProvider =
    FutureProvider.autoDispose<MonthlyRegister>((ref) async {
  final classLabel = ref.watch(officeAttendanceClassProvider);
  final month = ref.watch(officeAttendanceMonthProvider);
  return ref.read(attendanceOfficeRepositoryProvider).fetchMonthlyRegister(
        query: ref.watch(repositoryQueryProvider),
        classLabel: classLabel,
        month: month,
      );
});

final officePendingProvider =
    FutureProvider.autoDispose<List<PendingAttendanceClass>>((ref) async {
  final date = ref.watch(officeAttendanceDateProvider);
  return ref.read(attendanceOfficeRepositoryProvider).fetchPending(
        query: ref.watch(repositoryQueryProvider),
        date: date,
      );
});

final officeConsecutiveAbsenceProvider =
    FutureProvider.autoDispose<List<ConsecutiveAbsenceStudent>>((ref) async {
  final days = ref.watch(officeConsecutiveDaysProvider);
  return ref.read(attendanceOfficeRepositoryProvider).fetchConsecutiveAbsences(
        query: ref.watch(repositoryQueryProvider),
        days: days,
      );
});

final officeShortAttendanceProvider =
    FutureProvider.autoDispose<List<ShortAttendanceStudent>>((ref) async {
  final threshold = ref.watch(officeShortAttendanceThresholdProvider);
  return ref.read(attendanceOfficeRepositoryProvider).fetchShortAttendance(
        query: ref.watch(repositoryQueryProvider),
        threshold: threshold,
      );
});

// --- Screen ------------------------------------------------------------------

/// Office / admin student-attendance workspace (ATT-1, ATT-2, ATT-4, ATT-D1,
/// ATT-D2). Read-only + export. No attendance-write path is exposed here.
class OfficeAttendanceScreen extends ConsumerWidget {
  const OfficeAttendanceScreen({super.key});

  static const _tabs = ['Register', 'Monthly', 'Pending', 'Alerts'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Office attendance'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: AksharaSpacing.s4),
              child: Center(child: AksharaFreshnessChip()),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final label in _tabs)
                Tab(
                  key: QaTestKeys.officeAttendanceTab(label),
                  text: label,
                ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RegisterTab(),
            _MonthlyTab(),
            _PendingTab(),
            _AlertsTab(),
          ],
        ),
      ),
    );
  }
}

// --- Shared filter bar -------------------------------------------------------

class _ClassDateFilterBar extends ConsumerWidget {
  const _ClassDateFilterBar({this.showDate = true, this.showMonth = false});

  final bool showDate;
  final bool showMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classLabel = ref.watch(officeAttendanceClassProvider);
    final date = ref.watch(officeAttendanceDateProvider);
    final month = ref.watch(officeAttendanceMonthProvider);

    return Wrap(
      spacing: AksharaSpacing.s3,
      runSpacing: AksharaSpacing.s3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 160,
          child: TextFormField(
            key: QaTestKeys.officeAttendanceClassField,
            initialValue: classLabel,
            decoration: const InputDecoration(
              labelText: 'Class',
              hintText: 'e.g. 8-A',
              isDense: true,
            ),
            onChanged: (value) => ref
                .read(officeAttendanceClassProvider.notifier)
                .state = value.trim(),
          ),
        ),
        if (showDate)
          OutlinedButton.icon(
            key: QaTestKeys.officeAttendanceDateField,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(_dateLabel(date)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                ref.read(officeAttendanceDateProvider.notifier).state =
                    DateTime(picked.year, picked.month, picked.day);
              }
            },
          ),
        if (showMonth)
          SizedBox(
            width: 140,
            child: TextFormField(
              key: QaTestKeys.officeAttendanceMonthField,
              initialValue: month,
              decoration: const InputDecoration(
                labelText: 'Month',
                hintText: 'YYYY-MM',
                isDense: true,
              ),
              onChanged: (value) => ref
                  .read(officeAttendanceMonthProvider.notifier)
                  .state = value.trim(),
            ),
          ),
      ],
    );
  }
}

String _dateLabel(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Widget _exportRow({
  required VoidCallback onCsv,
  required VoidCallback onPdf,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      OutlinedButton.icon(
        key: QaTestKeys.officeAttendanceExportCsvButton,
        onPressed: onCsv,
        icon: const Icon(Icons.table_view_outlined, size: 18),
        label: const Text('CSV'),
      ),
      const SizedBox(width: AksharaSpacing.s2),
      OutlinedButton.icon(
        key: QaTestKeys.officeAttendanceExportPdfButton,
        onPressed: onPdf,
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: const Text('PDF'),
      ),
    ],
  );
}

Widget _tabBody({required Widget child}) {
  return Builder(
    builder: (context) => SingleChildScrollView(
      child: AdminLayout.constrainContent(
        context: context,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s4),
          child: child,
        ),
      ),
    ),
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

// --- ATT-1 Register tab ------------------------------------------------------

class _RegisterTab extends ConsumerWidget {
  const _RegisterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(officeRegisterProvider);
    final classLabel = ref.watch(officeAttendanceClassProvider);
    final date = ref.watch(officeAttendanceDateProvider);

    return _tabBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ClassDateFilterBar(),
          const SizedBox(height: AksharaSpacing.s4),
          AksharaSectionHeader(
            title: 'Register · $classLabel · ${_dateLabel(date)}',
          ),
          const SizedBox(height: AksharaSpacing.s2),
          async.when(
            loading: () => const AksharaLoadingState(),
            error: (e, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(e),
              onRetry: () => ref.invalidate(officeRegisterProvider),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const AksharaEmptyState(
                  message:
                      'No submitted attendance for this class and date yet.',
                  icon: Icons.event_busy_outlined,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RegisterSummary(rows: rows),
                  const SizedBox(height: AksharaSpacing.s3),
                  _RegisterList(rows: rows),
                  const SizedBox(height: AksharaSpacing.s3),
                  _exportRow(
                    onCsv: () => _export(context, ref, rows, pdf: false),
                    onPdf: () => _export(context, ref, rows, pdf: true),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<AttendanceRegisterEntry> rows, {
    required bool pdf,
  }) async {
    final classLabel = ref.read(officeAttendanceClassProvider);
    final date = _dateLabel(ref.read(officeAttendanceDateProvider));
    const headers = ['Roll', 'Student', 'Class', 'Mark'];
    final grid = [
      for (final r in rows) [r.roll ?? '', r.name, r.classLabel, r.mark],
    ];
    final service = ref.read(aksharaReportExportServiceProvider);
    final base = 'attendance_register_${classLabel}_$date'
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
    if (pdf) {
      await service.shareGridPdf(
        filename: base,
        reportTitle: 'Attendance Register',
        moduleLabel: 'Class $classLabel · $date',
        headers: headers,
        rows: grid,
      );
    } else {
      await service.shareGridCsv(filename: base, headers: headers, rows: grid);
    }
    if (!context.mounted) return;
    _snack(context,
        'Register ${pdf ? 'PDF' : 'CSV'} ready (${rows.length} students)');
  }
}

class _RegisterSummary extends StatelessWidget {
  const _RegisterSummary({required this.rows});

  final List<AttendanceRegisterEntry> rows;

  @override
  Widget build(BuildContext context) {
    int count(String mark) =>
        rows.where((r) => r.mark.toLowerCase() == mark).length;
    return Wrap(
      spacing: AksharaSpacing.s2,
      children: [
        _StatChip(label: 'Present', value: count('present'), color: Colors.green),
        _StatChip(label: 'Absent', value: count('absent'), color: Colors.red),
        _StatChip(label: 'Late', value: count('late'), color: Colors.orange),
        _StatChip(
            label: 'Excused', value: count('excused'), color: Colors.blueGrey),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text('$value',
            style: const TextStyle(fontSize: 11, color: Colors.white)),
      ),
      label: Text(label),
    );
  }
}

class _RegisterList extends StatelessWidget {
  const _RegisterList({required this.rows});

  final List<AttendanceRegisterEntry> rows;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final r in rows)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(r.roll ?? '–')),
                title: Text(r.name),
                subtitle: Text('${r.classLabel} · Roll ${r.roll ?? '–'}'),
                trailing: _MarkBadge(mark: r.mark),
              ),
            ),
        ],
      );
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Roll')),
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Mark')),
          ],
          rows: [
            for (final r in rows)
              DataRow(cells: [
                DataCell(Text(r.roll ?? '–')),
                DataCell(Text(r.name)),
                DataCell(Text(r.classLabel)),
                DataCell(_MarkBadge(mark: r.mark)),
              ]),
          ],
        ),
      ),
    );
  }
}

class _MarkBadge extends StatelessWidget {
  const _MarkBadge({required this.mark});

  final String mark;

  @override
  Widget build(BuildContext context) {
    final color = switch (mark.toLowerCase()) {
      'present' => Colors.green,
      'absent' => Colors.red,
      'late' => Colors.orange,
      'half_day' => Colors.indigo,
      'excused' => Colors.blueGrey,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(mark),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

// --- ATT-2 Monthly tab -------------------------------------------------------

class _MonthlyTab extends ConsumerWidget {
  const _MonthlyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(officeMonthlyRegisterProvider);
    final classLabel = ref.watch(officeAttendanceClassProvider);
    final month = ref.watch(officeAttendanceMonthProvider);

    return _tabBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ClassDateFilterBar(showDate: false, showMonth: true),
          const SizedBox(height: AksharaSpacing.s4),
          AksharaSectionHeader(title: 'Monthly register · $classLabel · $month'),
          const SizedBox(height: AksharaSpacing.s2),
          async.when(
            loading: () => const AksharaLoadingState(),
            error: (e, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(e),
              onRetry: () => ref.invalidate(officeMonthlyRegisterProvider),
            ),
            data: (register) {
              if (register.students.isEmpty) {
                return const AksharaEmptyState(
                  message: 'No submitted attendance for this class this month.',
                  icon: Icons.calendar_month_outlined,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MonthlyMatrix(register: register),
                  const SizedBox(height: AksharaSpacing.s3),
                  _exportRow(
                    onCsv: () => _export(context, ref, register, pdf: false),
                    onPdf: () => _export(context, ref, register, pdf: true),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    MonthlyRegister register, {
    required bool pdf,
  }) async {
    final dayHeaders = [
      for (var d = 1; d <= register.dayCount; d++) '$d',
    ];
    final headers = ['Roll', 'Student', ...dayHeaders, '%'];
    final grid = [
      for (final s in register.students)
        [
          s.roll ?? '',
          s.name,
          for (var d = 1; d <= register.dayCount; d++) s.codeForDay(d),
          '${s.percentPresent}',
        ],
    ];
    final service = ref.read(aksharaReportExportServiceProvider);
    final base = 'attendance_monthly_${register.classLabel}_${register.month}'
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
    if (pdf) {
      await service.shareGridPdf(
        filename: base,
        reportTitle: 'Monthly Attendance Register',
        moduleLabel: 'Class ${register.classLabel} · ${register.month}',
        headers: headers,
        rows: grid,
        rightAlignFrom: headers.length - 1,
      );
    } else {
      await service.shareGridCsv(filename: base, headers: headers, rows: grid);
    }
    if (!context.mounted) return;
    _snack(context,
        'Monthly ${pdf ? 'PDF' : 'CSV'} ready (${register.students.length} students)');
  }
}

class _MonthlyMatrix extends StatelessWidget {
  const _MonthlyMatrix({required this.register});

  final MonthlyRegister register;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12,
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: [
            const DataColumn(label: Text('Roll')),
            const DataColumn(label: Text('Student')),
            for (var d = 1; d <= register.dayCount; d++)
              DataColumn(label: Text('$d')),
            const DataColumn(label: Text('%')),
          ],
          rows: [
            for (final s in register.students)
              DataRow(cells: [
                DataCell(Text(s.roll ?? '–')),
                DataCell(Text(s.name)),
                for (var d = 1; d <= register.dayCount; d++)
                  DataCell(Text(s.codeForDay(d))),
                DataCell(Text('${s.percentPresent}%')),
              ]),
          ],
        ),
      ),
    );
  }
}

// --- ATT-4 Pending tab -------------------------------------------------------

class _PendingTab extends ConsumerWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(officePendingProvider);
    final date = ref.watch(officeAttendanceDateProvider);

    return _tabBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ClassDateFilterBar(),
          const SizedBox(height: AksharaSpacing.s4),
          AksharaSectionHeader(
            title: 'Attendance pending · ${_dateLabel(date)}',
          ),
          const SizedBox(height: AksharaSpacing.s2),
          async.when(
            loading: () => const AksharaLoadingState(),
            error: (e, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(e),
              onRetry: () => ref.invalidate(officePendingProvider),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const AksharaEmptyState(
                  message: 'All classes have submitted attendance. Nice.',
                  icon: Icons.check_circle_outline,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in rows)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          r.isDraft
                              ? Icons.hourglass_bottom_outlined
                              : Icons.error_outline,
                          color: r.isDraft ? Colors.orange : Colors.red,
                        ),
                        title: Text('Class ${r.classLabel}'),
                        subtitle: Text(
                          '${r.isDraft ? 'Draft not submitted' : 'Not started'}'
                          '${r.teacherName != null ? ' · ${r.teacherName}' : ''}'
                          '${r.lastSavedAt != null ? ' · saved ${_dateTimeLabel(r.lastSavedAt!)}' : ''}',
                        ),
                        trailing: Chip(
                          label: Text(r.isDraft ? 'Draft' : 'Missing'),
                        ),
                      ),
                    ),
                  const SizedBox(height: AksharaSpacing.s3),
                  _exportRow(
                    onCsv: () => _export(context, ref, rows, pdf: false),
                    onPdf: () => _export(context, ref, rows, pdf: true),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<PendingAttendanceClass> rows, {
    required bool pdf,
  }) async {
    final date = _dateLabel(ref.read(officeAttendanceDateProvider));
    const headers = ['Class', 'Status', 'Teacher', 'Last saved'];
    final grid = [
      for (final r in rows)
        [
          r.classLabel,
          r.isDraft ? 'Draft' : 'Missing',
          r.teacherName ?? '',
          r.lastSavedAt != null ? _dateTimeLabel(r.lastSavedAt!) : '',
        ],
    ];
    final service = ref.read(aksharaReportExportServiceProvider);
    final base = 'attendance_pending_$date'
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
    if (pdf) {
      await service.shareGridPdf(
        filename: base,
        reportTitle: 'Attendance Pending',
        moduleLabel: date,
        headers: headers,
        rows: grid,
      );
    } else {
      await service.shareGridCsv(filename: base, headers: headers, rows: grid);
    }
    if (!context.mounted) return;
    _snack(context,
        'Pending ${pdf ? 'PDF' : 'CSV'} ready (${rows.length} classes)');
  }
}

String _dateTimeLabel(DateTime dt) =>
    '${_dateLabel(dt)} ${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

// --- ATT-D1 + ATT-D2 Alerts tab ----------------------------------------------

class _AlertsTab extends ConsumerWidget {
  const _AlertsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _tabBody(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConsecutiveAbsenceSection(),
          SizedBox(height: AksharaSpacing.s6),
          _ShortAttendanceSection(),
        ],
      ),
    );
  }
}

class _ConsecutiveAbsenceSection extends ConsumerWidget {
  const _ConsecutiveAbsenceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(officeConsecutiveAbsenceProvider);
    final days = ref.watch(officeConsecutiveDaysProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AksharaSectionHeader(title: 'Consecutive absence ($days+ days)'),
        const SizedBox(height: AksharaSpacing.s2),
        SizedBox(
          width: 200,
          child: TextFormField(
            key: QaTestKeys.officeAttendanceConsecutiveDaysField,
            initialValue: '$days',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Days',
              isDense: true,
            ),
            onFieldSubmitted: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed >= 1 && parsed <= 60) {
                ref.read(officeConsecutiveDaysProvider.notifier).state = parsed;
              }
            },
          ),
        ),
        const SizedBox(height: AksharaSpacing.s2),
        async.when(
          loading: () => const AksharaLoadingState(),
          error: (e, _) => AksharaErrorState.fromFailure(
            apiFailureMapper.fromException(e),
            onRetry: () => ref.invalidate(officeConsecutiveAbsenceProvider),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const AksharaEmptyState(
                message: 'No students with consecutive absences.',
                icon: Icons.sentiment_satisfied_outlined,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in rows)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_outlined,
                          color: Colors.red),
                      title: Text(r.name),
                      subtitle: Text(
                        '${r.classLabel} · Roll ${r.roll ?? '–'} · '
                        '${r.consecutiveDays} consecutive days',
                      ),
                    ),
                  ),
                const SizedBox(height: AksharaSpacing.s3),
                _exportRow(
                  onCsv: () => _export(context, ref, rows, pdf: false),
                  onPdf: () => _export(context, ref, rows, pdf: true),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<ConsecutiveAbsenceStudent> rows, {
    required bool pdf,
  }) async {
    final days = ref.read(officeConsecutiveDaysProvider);
    const headers = ['Roll', 'Student', 'Class', 'Consecutive days'];
    final grid = [
      for (final r in rows)
        [r.roll ?? '', r.name, r.classLabel, '${r.consecutiveDays}'],
    ];
    final service = ref.read(aksharaReportExportServiceProvider);
    final base = 'attendance_consecutive_absence_${days}d';
    if (pdf) {
      await service.shareGridPdf(
        filename: base,
        reportTitle: 'Consecutive Absence',
        moduleLabel: '$days+ consecutive days',
        headers: headers,
        rows: grid,
      );
    } else {
      await service.shareGridCsv(filename: base, headers: headers, rows: grid);
    }
    if (!context.mounted) return;
    _snack(context,
        'Consecutive absence ${pdf ? 'PDF' : 'CSV'} ready (${rows.length} students)');
  }
}

class _ShortAttendanceSection extends ConsumerWidget {
  const _ShortAttendanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(officeShortAttendanceProvider);
    final threshold = ref.watch(officeShortAttendanceThresholdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AksharaSectionHeader(title: 'Short attendance (below $threshold%)'),
        const SizedBox(height: AksharaSpacing.s2),
        SizedBox(
          width: 200,
          child: TextFormField(
            key: QaTestKeys.officeAttendanceThresholdField,
            initialValue: '$threshold',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Threshold %',
              isDense: true,
            ),
            onFieldSubmitted: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed >= 1 && parsed <= 100) {
                ref.read(officeShortAttendanceThresholdProvider.notifier).state =
                    parsed;
              }
            },
          ),
        ),
        const SizedBox(height: AksharaSpacing.s2),
        async.when(
          loading: () => const AksharaLoadingState(),
          error: (e, _) => AksharaErrorState.fromFailure(
            apiFailureMapper.fromException(e),
            onRetry: () => ref.invalidate(officeShortAttendanceProvider),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return Text(
                'No students below $threshold%.',
                style: context.aksharaText.bodyMedium,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in rows)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _tierColor(r.percentPresent),
                        child: Text('${r.percentPresent}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white)),
                      ),
                      title: Text(r.name),
                      subtitle: Text(
                        '${r.classLabel} · Roll ${r.roll ?? '–'} · '
                        '${r.presentDays}/${r.markedDays} days · '
                        '${_tierLabel(r.percentPresent)}',
                      ),
                    ),
                  ),
                const SizedBox(height: AksharaSpacing.s3),
                _exportRow(
                  onCsv: () => _export(context, ref, rows, pdf: false),
                  onPdf: () => _export(context, ref, rows, pdf: true),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<ShortAttendanceStudent> rows, {
    required bool pdf,
  }) async {
    final threshold = ref.read(officeShortAttendanceThresholdProvider);
    const headers = ['Roll', 'Student', 'Class', 'Present', 'Marked', '%'];
    final grid = [
      for (final r in rows)
        [
          r.roll ?? '',
          r.name,
          r.classLabel,
          '${r.presentDays}',
          '${r.markedDays}',
          '${r.percentPresent}',
        ],
    ];
    final service = ref.read(aksharaReportExportServiceProvider);
    final base = 'attendance_short_below_$threshold';
    if (pdf) {
      await service.shareGridPdf(
        filename: base,
        reportTitle: 'Short Attendance',
        moduleLabel: 'Below $threshold%',
        headers: headers,
        rows: grid,
        rightAlignFrom: 3,
      );
    } else {
      await service.shareGridCsv(filename: base, headers: headers, rows: grid);
    }
    if (!context.mounted) return;
    _snack(context,
        'Short attendance ${pdf ? 'PDF' : 'CSV'} ready (${rows.length} students)');
  }
}

// Reuse the attendance-intelligence tier boundaries (<60 chronic, <75 at risk,
// <85 watch) for the short-attendance colour/label — this is a plain office
// list, not the intelligence dashboard, but the tier language stays consistent.
Color _tierColor(int percent) {
  if (percent < 60) return Colors.red;
  if (percent < 75) return Colors.deepOrange;
  if (percent < 85) return Colors.orange;
  return Colors.green;
}

String _tierLabel(int percent) {
  if (percent < 60) return 'Chronic';
  if (percent < 75) return 'At risk';
  if (percent < 85) return 'Watch';
  return 'Stable';
}
