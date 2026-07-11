import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_layout.dart';
import '../../admin/admin_shell.dart';
import '../../admin/models/admin_nav_models.dart';
import 'substitutions/daily_substitutions_screen.dart';
import 'timetable_editor_tab.dart';
import 'timetable_models.dart';
import 'timetable_provider.dart';
import 'timetable_workload_exporter.dart';

/// Timetable Optimizer hub — dashboard, generation, conflicts, workload, publish (v7.5).
class TimetableHubScreen extends ConsumerStatefulWidget {
  const TimetableHubScreen({super.key});

  @override
  ConsumerState<TimetableHubScreen> createState() => _TimetableHubScreenState();
}

class _TimetableHubScreenState extends ConsumerState<TimetableHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(timetableCanViewProvider)) {
      return const Scaffold(
        body: AksharaErrorState(
          message: 'Timetable scheduling is not enabled for your role.',
          icon: Icons.lock_outline,
        ),
      );
    }

    return AdminContentScaffold(
      breadcrumbs: const [
        AdminBreadcrumb(label: 'Management', route: '/management/dashboard'),
        AdminBreadcrumb(label: 'Timetable Optimizer'),
      ],
      onMenuTap: adminShellMenuTap(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabs,
            isScrollable: AdminLayout.isMobile(context),
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Generate'),
              Tab(text: 'Conflicts'),
              Tab(text: 'Workload'),
              Tab(text: 'Publish'),
              Tab(text: 'Editor'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _TimetableDashboardTab(),
                _TimetableGenerateTab(),
                _TimetableConflictsTab(),
                _TimetableWorkloadTab(),
                _TimetablePublishTab(),
                TimetableEditorTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimetableDashboardTab extends ConsumerWidget {
  const _TimetableDashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(timetableSummaryProvider);
    return ErpAsyncBody(
      state: resolveErpAsync(summaryAsync, isDataEmpty: (_) => false),
      loadingLabel: 'Loading timetable summary',
      emptyMessage: 'No timetable summary available.',
      onRetry: () => invalidateTimetableReads(ref),
      builder: (summary) => ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Wrap(
            spacing: AksharaSpacing.s3,
            runSpacing: AksharaSpacing.s3,
            children: [
              _KpiCard(label: 'Timetables', value: '${summary.totalTimetables}'),
              _KpiCard(label: 'Draft', value: '${summary.draftCount}'),
              _KpiCard(label: 'Validated', value: '${summary.validatedCount}'),
              _KpiCard(label: 'Published', value: '${summary.publishedCount}'),
              _KpiCard(label: 'Conflicts', value: '${summary.conflictCount}'),
              _KpiCard(label: 'Gaps', value: '${summary.gapCount}'),
              _KpiCard(label: 'Overloaded', value: '${summary.overloadedTeacherCount}'),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s4),
          Card(
            child: ListTile(
              leading: const Icon(Icons.swap_horiz_outlined),
              title: const Text("Today's timetable & cover"),
              subtitle:
                  const Text('Auto-fill periods when a teacher is on leave'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DailySubstitutionsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimetableGenerateTab extends ConsumerWidget {
  const _TimetableGenerateTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(timetableCanManageProvider);
    final mutation = ref.watch(timetableMutationsProvider);
    return Padding(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AksharaSectionHeader(title: 'Generate timetables'),
          const Text('Uses academic catalog teacher assignments as source of truth.'),
          const SizedBox(height: AksharaSpacing.s4),
          FilledButton.icon(
            onPressed: !canManage || mutation.isLoading
                ? null
                : () => ref.read(timetableMutationsProvider.notifier).generate(),
            icon: mutation.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_outlined),
            label: const Text('Generate school timetables'),
          ),
          if (mutation.hasError)
            Padding(
              padding: const EdgeInsets.only(top: AksharaSpacing.s3),
              child: Text('Generation failed: ${mutation.error}'),
            ),
        ],
      ),
    );
  }
}

class _TimetableConflictsTab extends ConsumerWidget {
  const _TimetableConflictsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(timetableConflictsProvider);
    return ErpAsyncBody(
      state: resolveErpAsync(
        conflictsAsync,
        isDataEmpty: (bundle) => bundle.conflicts.isEmpty,
      ),
      loadingLabel: 'Loading conflicts',
      emptyMessage: 'No timetable conflicts detected.',
      emptyIcon: Icons.check_circle_outline,
      onRetry: () => ref.invalidate(timetableConflictsProvider),
      builder: (bundle) {
        return ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            for (final conflict in bundle.conflicts)
              Card(
                child: ListTile(
                  leading: Icon(_iconForConflict(conflict.type)),
                  title: Text(conflict.message),
                  subtitle: Text('Day ${conflict.dayOfWeek} · Period ${conflict.periodNumber}'),
                ),
              ),
            if (bundle.recommendations.isNotEmpty) ...[
              const SizedBox(height: AksharaSpacing.s4),
              const AksharaSectionHeader(title: 'AI scheduling suggestions (read-only)'),
              for (final tip in bundle.recommendations)
                ListTile(
                  leading: const Icon(Icons.lightbulb_outline),
                  title: Text(tip),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Roadmap gap #9 — the per-teacher workload dashboard, powered by the unified
/// rollup (`/academic/timetables/workload/rollup`). A summary header
/// (total / over / under / balanced / avg periods) sits over a per-teacher list,
/// each row colour-coded by status with period count + section & subject chips.
class _TimetableWorkloadTab extends ConsumerWidget {
  const _TimetableWorkloadTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rollupAsync = ref.watch(timetableWorkloadRollupProvider);
    return ErpAsyncBody(
      state: resolveErpAsync(rollupAsync, isDataEmpty: (_) => false),
      loadingLabel: 'Loading teacher workload',
      emptyMessage: 'No teacher workload data available.',
      onRetry: () => ref.invalidate(timetableWorkloadRollupProvider),
      builder: (rollup) => TimetableWorkloadDashboard(
        rollup: rollup,
        onExport: () => TimetableWorkloadExporter(
          ref.read(aksharaReportExportServiceProvider),
        ).shareCsv(rollup),
      ),
    );
  }
}

/// The presentational workload dashboard (roadmap gap #9). Renders a summary
/// header + a per-teacher list colour-coded by over/under/balanced status with
/// section & subject chips, or an honest empty state when [rollup] has no
/// teachers. Pure widget over a [WorkloadRollup] so it's directly testable.
class TimetableWorkloadDashboard extends StatelessWidget {
  const TimetableWorkloadDashboard({
    super.key,
    required this.rollup,
    this.onExport,
  });

  final WorkloadRollup rollup;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    // Honest empty state: no scheduled grid → no workload to show.
    if (rollup.teachers.isEmpty) {
      return const AksharaEmptyState(
        key: QaTestKeys.timetableWorkloadEmptyState,
        title: 'No workload yet',
        message: 'Generate and publish a timetable to see per-teacher workload.',
        icon: Icons.balance_outlined,
      );
    }
    return ListView(
      key: QaTestKeys.timetableWorkloadDashboard,
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        _WorkloadSummaryHeader(summary: rollup.summary),
        const SizedBox(height: AksharaSpacing.s3),
        if (onExport != null)
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: QaTestKeys.timetableWorkloadExportButton,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export CSV'),
              onPressed: onExport,
            ),
          ),
        const SizedBox(height: AksharaSpacing.s2),
        for (final teacher in rollup.teachers)
          Padding(
            padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
            child: _WorkloadTeacherCard(teacher: teacher),
          ),
      ],
    );
  }
}

class _WorkloadSummaryHeader extends StatelessWidget {
  const _WorkloadSummaryHeader({required this.summary});

  final WorkloadRollupSummary summary;

  @override
  Widget build(BuildContext context) {
    final akshara = context.akshara;
    return Card(
      key: QaTestKeys.timetableWorkloadSummaryHeader,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Teacher workload', style: context.aksharaText.titleMedium),
            const SizedBox(height: AksharaSpacing.s3),
            Wrap(
              spacing: AksharaSpacing.s3,
              runSpacing: AksharaSpacing.s3,
              children: [
                _SummaryStat(label: 'Teachers', value: '${summary.totalTeachers}'),
                _SummaryStat(
                  label: 'Overloaded',
                  value: '${summary.overloaded}',
                  color: context.colors.error,
                ),
                _SummaryStat(
                  label: 'Underloaded',
                  value: '${summary.underloaded}',
                  color: akshara.warning,
                ),
                _SummaryStat(
                  label: 'Balanced',
                  value: '${summary.balanced}',
                  color: akshara.success,
                ),
                _SummaryStat(
                  label: 'Avg periods',
                  value: _formatAvg(summary.avgPeriods),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatAvg(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: context.aksharaText.headlineSmall.copyWith(color: color),
          ),
          Text(label, style: context.aksharaText.labelMedium),
        ],
      ),
    );
  }
}

class _WorkloadTeacherCard extends StatelessWidget {
  const _WorkloadTeacherCard({required this.teacher});

  final TeacherWorkloadRollup teacher;

  @override
  Widget build(BuildContext context) {
    final (accent, statusLabel) = _statusStyle(context, teacher.status);
    return Card(
      key: QaTestKeys.timetableWorkloadRow(teacher.teacherId),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.teacherName,
                        style: context.aksharaText.titleSmall,
                      ),
                      Text(
                        '${teacher.periodCount} periods / week',
                        style: context.aksharaText.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: accent.withValues(alpha: 0.15),
                  side: BorderSide(color: accent),
                  labelStyle: context.aksharaText.labelSmall.copyWith(color: accent),
                ),
              ],
            ),
            if (teacher.sections.isNotEmpty) ...[
              const SizedBox(height: AksharaSpacing.s2),
              _ChipRow(
                icon: Icons.class_outlined,
                labels: teacher.sections,
              ),
            ],
            if (teacher.subjectIds.isNotEmpty) ...[
              const SizedBox(height: AksharaSpacing.s2),
              _ChipRow(
                icon: Icons.menu_book_outlined,
                labels: teacher.subjectIds,
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, String) _statusStyle(BuildContext context, TeacherWorkloadStatus status) {
    final akshara = context.akshara;
    return switch (status) {
      TeacherWorkloadStatus.over => (context.colors.error, 'Overloaded'),
      TeacherWorkloadStatus.under => (akshara.warning, 'Under-utilised'),
      TeacherWorkloadStatus.balanced => (akshara.success, 'Balanced'),
    };
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.icon, required this.labels});

  final IconData icon;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AksharaSpacing.s1),
          child: Icon(icon, size: 16, color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(width: AksharaSpacing.s2),
        Expanded(
          child: Wrap(
            spacing: AksharaSpacing.s2,
            runSpacing: AksharaSpacing.s1,
            children: [
              for (final label in labels)
                Chip(
                  label: Text(label),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  labelStyle: context.aksharaText.labelSmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimetablePublishTab extends ConsumerWidget {
  const _TimetablePublishTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(timetableListProvider);
    final selectedId = ref.watch(timetableSelectedIdProvider);
    final canPublish = ref.watch(timetableCanPublishProvider);
    final mutation = ref.watch(timetableMutationsProvider);

    return ErpAsyncBody(
      state: resolveErpAsync(listAsync, isDataEmpty: (_) => false),
      loadingLabel: 'Loading timetables',
      emptyMessage: 'No timetables available.',
      onRetry: () => ref.invalidate(timetableListProvider),
      builder: (entries) {
        final validated = entries.where((e) => e.status == TimetableStatus.validated).toList();
        if (validated.isEmpty) {
          return const AksharaEmptyState(
            message: 'Validate a draft timetable before publishing.',
            icon: Icons.publish_outlined,
          );
        }
        return Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedId ?? validated.first.id,
                items: [
                  for (final entry in validated)
                    DropdownMenuItem(
                      value: entry.id,
                      child: Text('${entry.sectionId} · v${entry.version}'),
                    ),
                ],
                onChanged: (value) =>
                    ref.read(timetableSelectedIdProvider.notifier).state = value,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              OutlinedButton(
                onPressed: !ref.watch(timetableCanManageProvider) || mutation.isLoading
                    ? null
                    : () => ref.read(timetableMutationsProvider.notifier).validate(
                          selectedId ?? validated.first.id,
                        ),
                child: const Text('Validate selected'),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              FilledButton.icon(
                onPressed: !canPublish || mutation.isLoading
                    ? null
                    : () => ref.read(timetableMutationsProvider.notifier).publish(
                          selectedId ?? validated.first.id,
                        ),
                icon: const Icon(Icons.publish_outlined),
                label: const Text('Publish validated timetable'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.aksharaText.labelLarge),
              Text(value, style: context.aksharaText.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconForConflict(TimetableConflictType type) => switch (type) {
      TimetableConflictType.teacher => Icons.person_outline,
      TimetableConflictType.section => Icons.class_outlined,
      TimetableConflictType.room => Icons.meeting_room_outlined,
    };
