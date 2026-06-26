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

class DirectorAdmissionsScreen extends ConsumerWidget {
  const DirectorAdmissionsScreen({super.key});

  static const _filters = ['Current Quarter', 'Source', 'School'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorAdmissionsProvider);
    return CopilotContextScope(
      module: 'director',
      screen: 'Director Admissions Performance',
      child: DirectorModuleScaffold(
        screen: DirectorScreen.admissions,
        filters: _filters,
        filterTrailing: const DirectorAiAssistantLink(
          screenLabel: 'Director Admissions Performance',
        ),
        body: state.when(
          loading: () => const AksharaLoadingState(),
          error: (error, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(error)),
          data: (admissions) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AksharaSpacing.s3,
                runSpacing: AksharaSpacing.s3,
                children: [
                  DirectorMetricTile(
                    label: 'Inquiries',
                    value: '${admissions.inquiries}',
                  ),
                  DirectorMetricTile(
                    label: 'Applications',
                    value: '${admissions.applications}',
                  ),
                  DirectorMetricTile(
                    label: 'Interviews',
                    value: '${admissions.interviews}',
                  ),
                  DirectorMetricTile(
                    label: 'Enrolled',
                    value: '${admissions.enrolled}',
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s4),
              AksharaInsightCard(
                message:
                    'Chain conversion rate is ${admissions.conversionPercent}% with stronger outcomes at North Campus.',
                icon: Icons.auto_graph_outlined,
                actionLabel: 'Open Growth',
                onAction: () => context.go(RouteNames.directorGrowth),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
