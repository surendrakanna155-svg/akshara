import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../theme/spacing.dart';
import '../sis_models.dart';
import '../widgets/sis_module_scaffold.dart';
import 'academic_operations_mutations_provider.dart';
import 'academic_operations_providers.dart';

class SisSectionBalanceScreen extends ConsumerStatefulWidget {
  const SisSectionBalanceScreen({super.key});

  @override
  ConsumerState<SisSectionBalanceScreen> createState() =>
      _SisSectionBalanceScreenState();
}

class _SisSectionBalanceScreenState
    extends ConsumerState<SisSectionBalanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectionPlan = ref.watch(sectionBalancePreviewFutureProvider);
    final quarterlyPlan = ref.watch(quarterlyReshufflePreviewFutureProvider);
    final performancePlan = ref.watch(performanceBalancePreviewFutureProvider);

    return SisModuleScaffold(
      screen: SisScreen.sectionBalance,
      showFilterBar: false,
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            children: [
              TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Section Balance'),
                  Tab(text: 'Quarterly'),
                  Tab(text: 'Performance'),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s3),
              SizedBox(
                height: 420,
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _SectionPlanTab(
                      plan: sectionPlan,
                      execute: (planId) => ref
                          .read(executeOperationPlanProvider.notifier)
                          .executeSectionBalance(planId: planId),
                    ),
                    _QuarterlyPlanTab(
                      plan: quarterlyPlan,
                      execute: (planId) => ref
                          .read(executeOperationPlanProvider.notifier)
                          .executeQuarterly(planId: planId),
                    ),
                    _PerformancePlanTab(
                      plan: performancePlan,
                      execute: (planId) => ref
                          .read(executeOperationPlanProvider.notifier)
                          .executePerformance(planId: planId),
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

class _SectionPlanTab extends ConsumerWidget {
  const _SectionPlanTab({required this.plan, required this.execute});

  final AsyncValue<dynamic> plan;
  final Future<void> Function(String planId) execute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErpAsyncBody(
      state: resolveErpAsync(plan, isDataEmpty: (_) => false),
      loadingLabel: 'Loading',
      emptyMessage: 'No section balance plan available.',
      onRetry: () => ref.invalidate(sectionBalancePreviewFutureProvider),
      builder: (data) => Column(
        children: [
          Text('Target section size: ${data.targetSectionSize}'),
          const SizedBox(height: AksharaSpacing.s2),
          SizedBox(
            height: 280,
            child: ListView(
              children: [
                for (final row in data.previewRows)
                  ListTile(
                    key: QaTestKeys.sisSectionBalancePreviewRow(row.studentId),
                    title: Text(row.studentName),
                    subtitle: Text('${row.fromSection} -> ${row.toSection}'),
                  ),
              ],
            ),
          ),
          FilledButton(
            key: QaTestKeys.sisSectionBalanceExecuteButton,
            onPressed: () => execute(data.id),
            child: const Text('Execute section balance'),
          ),
        ],
      ),
    );
  }
}

class _QuarterlyPlanTab extends ConsumerWidget {
  const _QuarterlyPlanTab({required this.plan, required this.execute});

  final AsyncValue<dynamic> plan;
  final Future<void> Function(String planId) execute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quarter = ref.watch(quarterlyQuarterProvider);
    return Column(
      children: [
        DropdownButton<int>(
          value: quarter,
          items: const [
            DropdownMenuItem(value: 1, child: Text('Q1')),
            DropdownMenuItem(value: 2, child: Text('Q2')),
            DropdownMenuItem(value: 3, child: Text('Q3')),
            DropdownMenuItem(value: 4, child: Text('Q4')),
          ],
          onChanged: (value) {
            if (value == null) return;
            ref.read(quarterlyQuarterProvider.notifier).state = value;
            ref.invalidate(quarterlyReshufflePreviewFutureProvider);
          },
        ),
        SizedBox(
          height: 280,
          child: ErpAsyncBody(
            state: resolveErpAsync(plan, isDataEmpty: (_) => false),
            loadingLabel: 'Loading',
            emptyMessage: 'No quarterly reshuffle plan available.',
            onRetry: () =>
                ref.invalidate(quarterlyReshufflePreviewFutureProvider),
            builder: (data) => ListView(
              children: [
                for (final row in data.previewRows)
                  ListTile(
                    key: QaTestKeys.sisQuarterlyPreviewRow(row.studentId),
                    title: Text(row.studentName),
                    subtitle: Text('${row.fromSection} -> ${row.toSection}'),
                  ),
              ],
            ),
          ),
        ),
        FilledButton(
          key: QaTestKeys.sisQuarterlyExecuteButton,
          onPressed: plan.valueOrNull == null ? null : () => execute(plan.value.id),
          child: const Text('Execute quarterly reshuffle'),
        ),
      ],
    );
  }
}

class _PerformancePlanTab extends StatelessWidget {
  const _PerformancePlanTab({required this.plan, required this.execute});

  final AsyncValue<dynamic> plan;
  final Future<void> Function(String planId) execute;

  @override
  Widget build(BuildContext context) {
    return plan.when(
      data: (data) => Column(
        children: [
          SizedBox(
            height: 280,
            child: ListView(
              children: [
                for (final row in data.previewRows)
                  ListTile(
                    key: QaTestKeys.sisPerformancePreviewRow(row.studentId),
                    title: Text(row.studentName),
                    subtitle: Text('${row.fromSection} -> ${row.toSection}'),
                  ),
              ],
            ),
          ),
          FilledButton(
            key: QaTestKeys.sisPerformanceExecuteButton,
            onPressed: () => execute(data.id),
            child: const Text('Execute performance balance'),
          ),
        ],
      ),
      loading: () => const AksharaLoadingState(),
      error: (error, _) =>
          AksharaErrorState.fromFailure(apiFailureMapper.fromException(error)),
    );
  }
}
