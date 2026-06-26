import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_names.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../copilot/copilot_context_provider.dart';
import 'director_navigation.dart';
import 'director_providers.dart';
import 'widgets/director_module_scaffold.dart';
import 'widgets/director_shared_widgets.dart';
import '../../core/errors/api_failure_mapper.dart';

class DirectorPortfolioScreen extends ConsumerWidget {
  const DirectorPortfolioScreen({super.key});

  static const _filters = ['Metric Group', 'Quarter', 'Compare Schools'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorPortfolioProvider);
    return CopilotContextScope(
      module: 'director',
      screen: 'Director Portfolio Analytics',
      child: DirectorModuleScaffold(
        screen: DirectorScreen.portfolio,
        filters: _filters,
        filterTrailing: const DirectorAiAssistantLink(
          screenLabel: 'Director Portfolio Analytics',
        ),
        body: state.when(
          loading: () => const AksharaLoadingState(),
          error: (error, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(error)),
          data: (portfolio) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AksharaSpacing.s3,
                runSpacing: AksharaSpacing.s3,
                children: [
                  DirectorMetricTile(
                    label: 'YoY Growth',
                    value: '${portfolio.yoyGrowthPercent}%',
                  ),
                  DirectorMetricTile(
                    label: 'Net Growth',
                    value: '${portfolio.netGrowth}',
                  ),
                  DirectorMetricTile(
                    label: 'Capacity Utilization',
                    value: '${portfolio.capacityPercent}%',
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s4),
              AksharaInsightCard(
                message:
                    'Portfolio trend indicates sustained growth with retention at ${portfolio.retentionTrend.last.value.toStringAsFixed(0)}%.',
                icon: Icons.insights_outlined,
                actionLabel: 'Open Reports',
                onAction: () => context.go(RouteNames.directorReports),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
