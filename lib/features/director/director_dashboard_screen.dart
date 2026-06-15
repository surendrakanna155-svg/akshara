import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../copilot/copilot_context_provider.dart';
import 'director_models.dart';
import 'director_navigation.dart';
import 'director_providers.dart';
import 'widgets/director_module_scaffold.dart';
import 'widgets/director_shared_widgets.dart';

class DirectorDashboardScreen extends ConsumerWidget {
  const DirectorDashboardScreen({super.key});

  static const _filters = ['All schools', 'Region', 'Quarter'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorExecutiveDashboardProvider);
    return CopilotContextScope(
      module: 'director',
      screen: 'Director Executive Dashboard',
      child: DirectorModuleScaffold(
        screen: DirectorScreen.dashboard,
        filters: _filters,
        filterTrailing: const DirectorAiAssistantLink(
          screenLabel: 'Director Executive Dashboard',
        ),
        body: state.when(
          loading: () => const AksharaLoadingState(),
          error: (error, _) => AksharaErrorState(message: '$error'),
          data: (data) => _DashboardBody(data: data),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final DirectorDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: QaTestKeys.directorDashboardScreen,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DirectorKpiRow(kpis: data.kpis),
        const SizedBox(height: AksharaSpacing.s5),
        const AksharaSectionHeader(title: 'School portfolio health'),
        const SizedBox(height: AksharaSpacing.s3),
        Wrap(
          spacing: AksharaSpacing.s3,
          runSpacing: AksharaSpacing.s3,
          children: [
            for (final school in data.schoolRows)
              SizedBox(
                width: 300,
                child: Card(
                  child: ListTile(
                    title: Text(school.schoolName),
                    subtitle: Text(
                      '${school.location} · ${school.students} students · ${school.revenueCr} Cr',
                    ),
                    trailing: DirectorSchoolStatusChip(status: school.status),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s5),
        DirectorExecutiveSummaryCard(summary: data.executiveSummary),
      ],
    );
  }
}
