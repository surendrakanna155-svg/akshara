import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme_extensions.dart';
import 'multi_school_models.dart';
import 'multi_school_mutations_provider.dart';
import 'multi_school_providers.dart';
import '../../../theme/spacing.dart';

class MultiSchoolPortfolioScreen extends ConsumerWidget {
  const MultiSchoolPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(multiSchoolPortfolioDashboardProvider);
    final schoolsState = ref.watch(multiSchoolSchoolsProvider);
    final alertsState = ref.watch(multiSchoolAlertsProvider);

    return Scaffold(
      key: QaTestKeys.multiSchoolPortfolioScreen,
      appBar: AppBar(
        title: const Text('Multi-School Portfolio'),
        actions: [
          TextButton.icon(
            key: QaTestKeys.multiSchoolOnboardingCta,
            onPressed: () => context.push(RouteNames.multiSchoolOnboarding),
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Onboard'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          dashboardState.when(
            loading: () => const AksharaLoadingState(),
            error: (error, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(error),
              onRetry: () =>
                  ref.invalidate(multiSchoolPortfolioDashboardProvider),
            ),
            data: (dashboard) => _KpiRow(kpis: dashboard.kpis),
          ),
          const SizedBox(height: 16),
          _FilterChips(),
          const SizedBox(height: 12),
          const Text(
            'Portfolio Alerts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          alertsState.when(
            loading: () => const SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(error),
              onRetry: () => ref.invalidate(multiSchoolAlertsProvider),
            ),
            data: (alerts) => _AlertsList(alerts: alerts),
          ),
          const SizedBox(height: 16),
          const Text(
            'School Lifecycle',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          schoolsState.when(
            loading: () => const AksharaLoadingState(),
            error: (error, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(error),
              onRetry: () => ref.invalidate(multiSchoolSchoolsProvider),
            ),
            data: (schools) => _SchoolList(schools: schools),
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis});

  final List<PortfolioKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final kpi in kpis)
          SizedBox(
            width: 220,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kpi.label,
                      style: context.aksharaText.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kpi.value,
                      style: context.aksharaText.headlineSmall,
                    ),
                    if (kpi.deltaLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        kpi.deltaLabel!,
                        style: context.aksharaText.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(multiSchoolLifecycleFilterProvider);
    final choices = <SchoolLifecycleStatus?>[
      null,
      ...SchoolLifecycleStatus.values,
    ];

    return Wrap(
      spacing: 8,
      children: [
        for (final choice in choices)
          ChoiceChip(
            label: Text(choice == null ? 'All' : choice.value),
            selected: selected == choice,
            onSelected: (_) {
              ref.read(multiSchoolLifecycleFilterProvider.notifier).state =
                  choice;
              ref.invalidate(multiSchoolSchoolsProvider);
            },
          ),
      ],
    );
  }
}

class _AlertsList extends ConsumerWidget {
  const _AlertsList({required this.alerts});

  final List<PortfolioAlert> alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alerts.isEmpty) {
      return const AksharaEmptyState(message: 'No active portfolio alerts.');
    }

    return Column(
      children: [
        for (final alert in alerts)
          Card(
            key: QaTestKeys.multiSchoolAlertCard(alert.id),
            child: ListTile(
              title: Text(alert.title),
              subtitle: Text('${alert.schoolName} - ${alert.message}'),
              trailing: IconButton(
                key: QaTestKeys.multiSchoolDismissAlertButton(alert.id),
                tooltip: 'Dismiss alert',
                icon: const Icon(Icons.close),
                onPressed: () async {
                  final result = await ref
                      .read(dismissPortfolioAlertProvider.notifier)
                      .execute(alertId: alert.id);
                  if (result == null || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      key: QaTestKeys.multiSchoolAlertDismissedSnackbar,
                      content: Text('Portfolio alert dismissed.'),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _SchoolList extends ConsumerWidget {
  const _SchoolList({required this.schools});

  final List<SchoolLifecycleRecord> schools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (schools.isEmpty) {
      return const AksharaEmptyState(message: 'No schools for this filter.');
    }

    return Column(
      children: [
        for (final school in schools)
          Card(
            key: QaTestKeys.multiSchoolSchoolRow(school.schoolId),
            child: ListTile(
              title: Text(school.schoolName),
              subtitle: Text('${school.planName} | ${school.region}'),
              trailing: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _HealthChip(score: school.healthScore.score),
                  if (school.status == SchoolLifecycleStatus.active)
                    IconButton(
                      key: QaTestKeys.multiSchoolDeactivateSchoolButton(
                        school.schoolId,
                      ),
                      tooltip: 'Deactivate',
                      onPressed: () =>
                          _deactivate(context, ref, school.schoolId),
                      icon: const Icon(Icons.pause_circle_outline),
                    )
                  else
                    IconButton(
                      key: QaTestKeys.multiSchoolActivateSchoolButton(
                        school.schoolId,
                      ),
                      tooltip: 'Activate',
                      onPressed: () => _activate(context, ref, school.schoolId),
                      icon: const Icon(Icons.play_circle_outline),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _activate(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
  ) async {
    final result = await ref
        .read(activateSchoolProvider.notifier)
        .execute(schoolId: schoolId);
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.multiSchoolActivationSnackbar,
        content: Text('School activated.'),
      ),
    );
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
  ) async {
    final result = await ref
        .read(deactivateSchoolProvider.notifier)
        .execute(schoolId: schoolId);
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.multiSchoolDeactivationSnackbar,
        content: Text('School deactivated.'),
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = switch (score) {
      >= 80 => context.akshara.success,
      >= 60 => context.akshara.warning,
      _ => context.colors.error,
    };
    return Chip(
      key: QaTestKeys.multiSchoolHealthChip(score),
      backgroundColor: color.withValues(alpha: 0.12),
      label: Text('Health $score'),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
