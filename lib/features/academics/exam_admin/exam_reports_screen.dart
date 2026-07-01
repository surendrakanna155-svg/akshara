import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'exam_reports_provider.dart';

/// EXM-3/4/5/7 — the cohesive "Exam Reports" area: Tabulation register, Merit
/// list + Subject toppers, Pass/Fail + grade distribution, and Datesheet. Each
/// tab exports the exact on-screen grid as CSV + PDF via the shared export
/// service (XCT-1 grid primitive). RBAC-gated on viewExams.
///
/// 🔴 Non-present (AB/ML/DB) rows are shown via their status code but are
/// EXCLUDED from every statistic — the repository/backend enforce this; the UI
/// only renders what it is given (the status code in the cell, no number).
class ExamReportsScreen extends ConsumerWidget {
  const ExamReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbac = ref.watch(rbacServiceProvider);
    if (!rbac.hasPermission(Permission.viewExams)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Reports')),
        body: const AksharaEmptyState(
          message: 'You do not have permission to view exam reports.',
          icon: Icons.lock_outline,
        ),
      );
    }

    final tab = ref.watch(examReportsTabProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Reports'),
        actions: [
          IconButton(
            key: QaTestKeys.examReportsExportCsvButton,
            tooltip: 'Export CSV',
            icon: const Icon(Icons.table_view_outlined),
            onPressed: () => _export(context, ref, tab, asPdf: false),
          ),
          IconButton(
            key: QaTestKeys.examReportsExportPdfButton,
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _export(context, ref, tab, asPdf: true),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ReportScopeBar(),
          _ReportTabBar(selected: tab),
          const Divider(height: 1),
          Expanded(child: _ReportBody(tab: tab)),
        ],
      ),
    );
  }

  /// Builds the current tab's grid (headers + rows) and shares it as CSV or PDF.
  /// The grid is identical to what the tab renders on screen.
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ExamReportTab tab, {
    required bool asPdf,
  }) async {
    final grid = _gridForTab(ref, tab);
    if (grid == null) {
      showAksharaExportQueuedSnackBar(
        context,
        label: 'Report still loading — try again in a moment.',
      );
      return;
    }
    if (grid.rows.isEmpty) {
      showAksharaExportQueuedSnackBar(
        context,
        label: 'No ${grid.title} rows to export.',
      );
      return;
    }

    final service = ref.read(aksharaReportExportServiceProvider);
    final filename = 'exam_${tab.keyName}';
    if (asPdf) {
      await service.shareGridPdf(
        filename: filename,
        reportTitle: grid.title,
        moduleLabel: grid.subtitle,
        headers: grid.headers,
        rows: grid.rows,
        rightAlignFrom: grid.rightAlignFrom,
      );
    } else {
      await service.shareGridCsv(
        filename: filename,
        headers: grid.headers,
        rows: grid.rows,
      );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${grid.title} ${asPdf ? 'PDF' : 'CSV'} ready (${grid.rows.length} rows)',
        ),
      ),
    );
  }

  /// Assembles the grid (title, headers, rows) for the active tab from the
  /// already-loaded report data. Returns null while the data is still loading.
  _ReportGrid? _gridForTab(WidgetRef ref, ExamReportTab tab) {
    final classLabel = ref.read(examReportsClassProvider);
    final term = ref.read(examReportsTermProvider);
    switch (tab) {
      case ExamReportTab.tabulation:
        final reg = ref.read(examTabulationProvider).valueOrNull;
        if (reg == null) return null;
        final headers = <String>[
          'Roll',
          'Student',
          ...reg.subjects,
          'Total',
          '%',
          'Rank',
        ];
        final rows = [
          for (final s in reg.students)
            <String>[
              s.rollNo ?? '',
              s.studentName,
              for (final subj in reg.subjects)
                s.cellsBySubject[subj]?.display ?? '—',
              '${s.total}/${s.totalMax}',
              '${s.percent.toStringAsFixed(1)}%',
              s.rank?.toString() ?? '—',
            ],
        ];
        return _ReportGrid(
          title: 'Tabulation Register',
          subtitle: '$classLabel · $term',
          headers: headers,
          rows: rows,
          rightAlignFrom: 2 + reg.subjects.length,
        );
      case ExamReportTab.meritToppers:
        final merit = ref.read(examMeritProvider).valueOrNull;
        if (merit == null) return null;
        return _ReportGrid(
          title: 'Merit List',
          subtitle: '$classLabel · $term',
          headers: const ['Rank', 'Student', 'Total', '%'],
          rows: [
            for (final m in merit)
              [
                '${m.rank}',
                m.studentName,
                '${m.total}/${m.totalMax}',
                '${m.percent.toStringAsFixed(1)}%',
              ],
          ],
          rightAlignFrom: 2,
        );
      case ExamReportTab.distribution:
        final dist = ref.read(examDistributionProvider).valueOrNull;
        if (dist == null) return null;
        return _ReportGrid(
          title: 'Pass / Fail + Grade Distribution',
          subtitle: 'Pass mark ${dist.passMarkPercent}% (${dist.passMarkSource})',
          headers: const ['Metric', 'Count'],
          rows: [
            ['Passed', '${dist.passCount}'],
            ['Failed', '${dist.failCount}'],
            for (final g in dist.gradeBreakdown) ['Grade ${g.grade}', '${g.count}'],
            ['Present (evaluated)', '${dist.presentCount}'],
            ['Excluded (AB/ML/DB)', '${dist.excludedCount}'],
          ],
          rightAlignFrom: 1,
        );
      case ExamReportTab.datesheet:
        final rows = ref.read(examDatesheetProvider).valueOrNull;
        if (rows == null) return null;
        return _ReportGrid(
          title: 'Datesheet',
          subtitle: '$classLabel · $term',
          headers: const ['Subject', 'Date', 'Time', 'Venue', 'Max marks'],
          rows: [
            for (final r in rows)
              [r.subject, r.dateLabel, r.timeLabel, r.venueLabel, '${r.maxMarks}'],
          ],
          rightAlignFrom: 4,
        );
    }
  }
}

class _ReportGrid {
  const _ReportGrid({
    required this.title,
    required this.subtitle,
    required this.headers,
    required this.rows,
    required this.rightAlignFrom,
  });
  final String title;
  final String subtitle;
  final List<String> headers;
  final List<List<String>> rows;
  final int rightAlignFrom;
}

/// Class + term (+ exam) pickers shared by all report tabs.
class _ReportScopeBar extends ConsumerWidget {
  const _ReportScopeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(examReportsClassOptionsProvider);
    final terms = ref.watch(examReportsTermOptionsProvider);
    final exams = ref.watch(examReportsExamOptionsProvider);
    final selectedClass = ref.watch(examReportsClassProvider);
    final selectedTerm = ref.watch(examReportsTermProvider);
    final selectedExam = ref.watch(examReportsExamIdProvider);
    final tab = ref.watch(examReportsTabProvider);
    final needsExam = tab == ExamReportTab.meritToppers ||
        tab == ExamReportTab.distribution;

    return Padding(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      child: Wrap(
        spacing: AksharaSpacing.s3,
        runSpacing: AksharaSpacing.s3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              key: QaTestKeys.examReportsClassField,
              initialValue: classes.contains(selectedClass) ? selectedClass : null,
              decoration: const InputDecoration(
                labelText: 'Class',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in classes)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(examReportsClassProvider.notifier).state = value;
                }
              },
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              key: QaTestKeys.examReportsTermField,
              initialValue: terms.contains(selectedTerm) ? selectedTerm : null,
              decoration: const InputDecoration(
                labelText: 'Term',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final t in terms) DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(examReportsTermProvider.notifier).state = value;
                }
              },
            ),
          ),
          if (needsExam)
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                key: QaTestKeys.examReportsExamSelector,
                initialValue:
                    exams.any((e) => e.id == selectedExam) ? selectedExam : null,
                decoration: const InputDecoration(
                  labelText: 'Exam',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final e in exams)
                    DropdownMenuItem(
                      value: e.id,
                      child: Text('${e.subject} · ${e.title}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  ref.read(examReportsExamIdProvider.notifier).state = value;
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportTabBar extends ConsumerWidget {
  const _ReportTabBar({required this.selected});

  final ExamReportTab selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s4),
      child: Row(
        children: [
          for (final t in ExamReportTab.values)
            Padding(
              padding: const EdgeInsets.only(right: AksharaSpacing.s2),
              child: ChoiceChip(
                key: QaTestKeys.examReportsTab(t.keyName),
                label: Text(t.label),
                selected: selected == t,
                onSelected: (_) =>
                    ref.read(examReportsTabProvider.notifier).state = t,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.tab});

  final ExamReportTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (tab) {
      ExamReportTab.tabulation => const _TabulationView(),
      ExamReportTab.meritToppers => const _MeritToppersView(),
      ExamReportTab.distribution => const _DistributionView(),
      ExamReportTab.datesheet => const _DatesheetView(),
    };
  }
}

class _TabulationView extends ConsumerWidget {
  const _TabulationView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(examTabulationProvider).when(
          loading: () =>
              const AksharaLoadingState(semanticLabel: 'Loading tabulation'),
          error: (_, __) =>
              const AksharaErrorState(message: 'Unable to load tabulation.'),
          data: (reg) {
            if (reg.students.isEmpty) {
              return const AksharaEmptyState(
                message: 'No results for this class and term yet.',
                icon: Icons.grid_on_outlined,
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Roll')),
                    const DataColumn(label: Text('Student')),
                    for (final s in reg.subjects) DataColumn(label: Text(s)),
                    const DataColumn(label: Text('Total')),
                    const DataColumn(label: Text('%')),
                    const DataColumn(label: Text('Rank')),
                  ],
                  rows: [
                    for (final s in reg.students)
                      DataRow(cells: [
                        DataCell(Text(s.rollNo ?? '')),
                        DataCell(Text(s.studentName)),
                        for (final subj in reg.subjects)
                          DataCell(Text(s.cellsBySubject[subj]?.display ?? '—')),
                        DataCell(Text('${s.total}/${s.totalMax}')),
                        DataCell(Text('${s.percent.toStringAsFixed(1)}%')),
                        DataCell(Text(s.rank?.toString() ?? '—')),
                      ]),
                  ],
                ),
              ),
            );
          },
        );
  }
}

class _MeritToppersView extends ConsumerWidget {
  const _MeritToppersView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    final merit = ref.watch(examMeritProvider);
    final toppers = ref.watch(examToppersProvider);

    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        Text('Subject toppers', style: text.titleMedium),
        const SizedBox(height: AksharaSpacing.s2),
        toppers.when(
          loading: () =>
              const AksharaLoadingState(semanticLabel: 'Loading toppers'),
          error: (_, __) =>
              const AksharaErrorState(message: 'Unable to load toppers.'),
          data: (rows) => rows.isEmpty
              ? const AksharaEmptyState(
                  message: 'No published marks for this exam yet.',
                  icon: Icons.emoji_events_outlined,
                )
              : Column(
                  children: [
                    for (final t in rows)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(child: Text('${t.rank}')),
                        title: Text(t.studentName),
                        trailing: Text(
                          '${t.marks}/${t.maxMarks} · ${t.percent.toStringAsFixed(1)}%',
                          style: text.bodyMedium,
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AksharaSpacing.s5),
        Text('Merit list (term total)', style: text.titleMedium),
        const SizedBox(height: AksharaSpacing.s2),
        merit.when(
          loading: () =>
              const AksharaLoadingState(semanticLabel: 'Loading merit list'),
          error: (_, __) =>
              const AksharaErrorState(message: 'Unable to load merit list.'),
          data: (rows) => rows.isEmpty
              ? const AksharaEmptyState(
                  message: 'No ranked students for this class and term yet.',
                  icon: Icons.leaderboard_outlined,
                )
              : Column(
                  children: [
                    for (final m in rows)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(child: Text('${m.rank}')),
                        title: Text(m.studentName),
                        trailing: Text(
                          '${m.total}/${m.totalMax} · ${m.percent.toStringAsFixed(1)}%',
                          style: text.bodyMedium,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DistributionView extends ConsumerWidget {
  const _DistributionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    return ref.watch(examDistributionProvider).when(
          loading: () =>
              const AksharaLoadingState(semanticLabel: 'Loading distribution'),
          error: (_, __) =>
              const AksharaErrorState(message: 'Unable to load distribution.'),
          data: (dist) {
            if (dist == null || dist.presentCount == 0) {
              return const AksharaEmptyState(
                message: 'No published marks for this exam yet.',
                icon: Icons.pie_chart_outline,
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Passed',
                        value: '${dist.passCount}',
                        tone: KpiAccent.success,
                      ),
                    ),
                    const SizedBox(width: AksharaSpacing.s3),
                    Expanded(
                      child: _StatCard(
                        label: 'Failed',
                        value: '${dist.failCount}',
                        tone: KpiAccent.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AksharaSpacing.s3),
                Text(
                  'Pass mark ${dist.passMarkPercent}% (${dist.passMarkSource}) · '
                  '${dist.presentCount} evaluated · '
                  '${dist.excludedCount} excluded (AB/ML/DB)',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AksharaSpacing.s4),
                Text('Grade distribution', style: text.titleMedium),
                const SizedBox(height: AksharaSpacing.s2),
                for (final g in dist.gradeBreakdown)
                  ListTile(
                    dense: true,
                    title: Text('Grade ${g.grade}'),
                    trailing: Text('${g.count}', style: text.bodyMedium),
                  ),
              ],
            );
          },
        );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final KpiAccent tone;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
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
            Text(value, style: text.headlineSmall),
            const SizedBox(height: AksharaSpacing.s1),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DatesheetView extends ConsumerWidget {
  const _DatesheetView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    return ref.watch(examDatesheetProvider).when(
          loading: () =>
              const AksharaLoadingState(semanticLabel: 'Loading datesheet'),
          error: (_, __) =>
              const AksharaErrorState(message: 'Unable to load datesheet.'),
          data: (rows) {
            if (rows.isEmpty) {
              return const AksharaEmptyState(
                message: 'No exams scheduled for this class and term.',
                icon: Icons.event_note_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AksharaSpacing.s2),
              itemBuilder: (context, index) {
                final r = rows[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AksharaSpacing.s3),
                    side: BorderSide(color: context.colors.outlineVariant),
                  ),
                  child: ListTile(
                    title: Text(r.subject, style: text.titleSmall),
                    subtitle: Text('${r.dateLabel} · ${r.timeLabel} · ${r.venueLabel}'),
                    trailing: Text('${r.maxMarks} marks', style: text.bodySmall),
                  ),
                );
              },
            );
          },
        );
  }
}
