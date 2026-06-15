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

class DirectorGrowthScreen extends ConsumerWidget {
  const DirectorGrowthScreen({super.key});

  static const _filters = ['24 Months', 'Retention', 'Capacity'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorGrowthProvider);
    return CopilotContextScope(
      module: 'director',
      screen: 'Director Growth Analytics',
      child: DirectorModuleScaffold(
        screen: DirectorScreen.growth,
        filters: _filters,
        filterTrailing: const DirectorAiAssistantLink(
          screenLabel: 'Director Growth Analytics',
        ),
        body: state.when(
          loading: () => const AksharaLoadingState(),
          error: (error, _) => AksharaErrorState(message: '$error'),
          data: (growth) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AksharaSpacing.s3,
                runSpacing: AksharaSpacing.s3,
                children: [
                  DirectorMetricTile(
                    label: 'YoY Growth',
                    value: '${growth.yoyGrowthPercent}%',
                  ),
                  DirectorMetricTile(
                    label: 'New Enrollments',
                    value: '${growth.newEnrollments}',
                  ),
                  DirectorMetricTile(
                    label: 'Withdrawals',
                    value: '${growth.withdrawals}',
                  ),
                  DirectorMetricTile(
                    label: 'Capacity',
                    value: '${growth.capacityPercent}%',
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s4),
              AksharaInsightCard(
                message:
                    'Enrollment forecast indicates net gain of ${growth.netGrowth} with stable retention.',
                icon: Icons.trending_up_outlined,
                actionLabel: 'View Admissions',
                onAction: () => context.go(RouteNames.directorAdmissions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
