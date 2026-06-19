import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_layout.dart';
import '../../admin/admin_shell.dart';
import '../../admin/models/admin_nav_models.dart';
import 'substitutions/daily_substitutions_screen.dart';
import 'timetable_editor_tab.dart';
import 'timetable_models.dart';
import 'timetable_provider.dart';

/// Smart Timetable hub — dashboard, generation, conflicts, workload, publish (v7.5).
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
        AdminBreadcrumb(label: 'Smart Timetable'),
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
    return summaryAsync.when(
      loading: () => const AksharaLoadingState(semanticLabel: 'Loading timetable summary'),
      error: (_, __) => AksharaErrorState(
        message: 'Unable to load timetable summary.',
        onRetry: () => invalidateTimetableReads(ref),
      ),
      data: (summary) => ListView(
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
    return conflictsAsync.when(
      loading: () => const AksharaLoadingState(semanticLabel: 'Loading conflicts'),
      error: (_, __) => const AksharaErrorState(message: 'Unable to load timetable conflicts.'),
      data: (bundle) {
        if (bundle.conflicts.isEmpty) {
          return const AksharaEmptyState(
            message: 'No timetable conflicts detected.',
            icon: Icons.check_circle_outline,
          );
        }
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

class _TimetableWorkloadTab extends ConsumerWidget {
  const _TimetableWorkloadTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workloadAsync = ref.watch(timetableWorkloadProvider);
    return workloadAsync.when(
      loading: () => const AksharaLoadingState(semanticLabel: 'Loading teacher workload'),
      error: (_, __) => const AksharaErrorState(message: 'Unable to load teacher workload.'),
      data: (entries) => ListView.separated(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: AksharaSpacing.s2),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            tileColor: entry.isOverloaded
                ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35)
                : null,
            title: Text(entry.teacherName),
            subtitle: Text('${entry.periodCount} periods / week'),
            trailing: entry.isOverloaded
                ? const Chip(label: Text('Overloaded'))
                : null,
          );
        },
      ),
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

    return listAsync.when(
      loading: () => const AksharaLoadingState(semanticLabel: 'Loading timetables'),
      error: (_, __) => const AksharaErrorState(message: 'Unable to load timetables.'),
      data: (entries) {
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
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
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
