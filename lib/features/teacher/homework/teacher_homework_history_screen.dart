import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'homework_models.dart';
import 'teacher_homework_provider.dart';

/// HWK-5 — teacher homework history with a due-date range filter and a CSV
/// export (via the shared report export service). Rides XCT-1.
class TeacherHomeworkHistoryScreen extends ConsumerWidget {
  const TeacherHomeworkHistoryScreen({super.key});

  String _iso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherHomeworkHistoryProvider);
    final range = ref.watch(teacherHomeworkHistoryRangeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const AksharaAppBar(
        titleText: 'Homework History',
        trailingPadding: true,
      ),
      // DS V2 P4 — premium persona canvas behind the history list.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          ref
                              .read(
                                  teacherHomeworkHistoryRangeProvider.notifier)
                              .state = HomeworkHistoryRange(
                            fromDate: _iso(picked.start),
                            toDate: _iso(picked.end),
                          );
                        }
                      },
                      icon: const Icon(Icons.date_range_outlined, size: 18),
                      label: Text(
                        range.fromDate == null
                            ? 'All dates'
                            : '${range.fromDate} → ${range.toDate}',
                      ),
                    ),
                  ),
                  if (range.fromDate != null) ...[
                    const SizedBox(width: AksharaSpacing.s2),
                    IconButton(
                      tooltip: 'Clear range',
                      onPressed: () => ref
                          .read(teacherHomeworkHistoryRangeProvider.notifier)
                          .state = const HomeworkHistoryRange(),
                      icon: const Icon(Icons.clear),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AksharaSpacing.s3),
              FilledButton.icon(
                key: QaTestKeys.teacherHomeworkHistoryExportButton,
                onPressed: (async.valueOrNull?.isEmpty ?? true)
                    ? null
                    : () => _exportCsv(context, ref, async.value!),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export CSV'),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              async.when(
                loading: () => const AksharaLoadingState(),
                error: (_, __) => const AksharaErrorState(
                  message: 'Unable to load homework history.',
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const AksharaEmptyState(
                      message: 'No homework in this date range.',
                      icon: Icons.history_outlined,
                      compact: true,
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items) _HistoryRow(item: item),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref,
    List<TeacherHomeworkHistoryItem> items,
  ) async {
    final service = ref.read(aksharaReportExportServiceProvider);
    await service.shareGridCsv(
      filename: 'homework_history',
      headers: const [
        'Assignment',
        'Class',
        'Subject',
        'Due date',
        'Submitted',
        'Total',
      ],
      rows: [
        for (final item in items)
          [
            item.title,
            item.classLabel,
            item.subject,
            item.dueDate ?? item.dueLabel,
            item.submittedCount.toString(),
            item.totalCount.toString(),
          ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final TeacherHomeworkHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${item.classLabel} · ${item.dueLabel}',
                  style:
                      text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Text(
            '${item.submittedCount}/${item.totalCount}',
            style: text.titleSmall.copyWith(color: colors.primary),
          ),
        ],
      ),
    );
  }
}
