import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../adaptive_ai/adaptive_ai_models.dart';
import '../adaptive_ai/widgets/adaptive_priority_feed.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../admin/admin_layout.dart';
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
        body: KeyedSubtree(
          key: QaTestKeys.directorDashboardScreen,
          child: ErpAsyncBody<DirectorDashboardData>(
            state: resolveErpAsync(state, isDataEmpty: (_) => false),
            loadingLabel: 'Loading',
            emptyMessage: 'No dashboard data available.',
            onRetry: () => ref.invalidate(directorExecutiveDashboardProvider),
            builder: (data) => SingleChildScrollView(
              child: _DashboardBody(data: data),
            ),
          ),
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
    // Phones stretch each health card full-width in a column; tablet/desktop
    // keep the fixed-width wrapped grid.
    final isMobile = AdminLayout.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DirectorKpiRow(kpis: data.kpis),
        const SizedBox(height: AksharaSpacing.s5),
        const AksharaSectionHeader(title: 'School portfolio health'),
        const SizedBox(height: AksharaSpacing.s3),
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final school in data.schoolRows) ...[
                _SchoolHealthCard(school: school),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          Wrap(
            spacing: AksharaSpacing.s3,
            runSpacing: AksharaSpacing.s3,
            children: [
              for (final school in data.schoolRows)
                SizedBox(
                  width: 320,
                  child: _SchoolHealthCard(school: school),
                ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s5),
        // W2 Adaptive AI — the aggregate director feed (self-hiding when empty).
        // Actions navigate to the org-scoped drill-down; the human acts there.
        AdaptivePriorityFeedSection(persona: 'director', onOpenAction: _openDirectorAction),
        const SizedBox(height: AksharaSpacing.s5),
        DirectorExecutiveSummaryCard(summary: data.executiveSummary),
      ],
    );
  }

  void _openDirectorAction(BuildContext context, AdaptiveAction action) {
    final link = action.deepLink;
    final route = link.startsWith('/finance')
        ? RouteNames.directorRevenue
        : link.contains('complian')
            ? RouteNames.directorCompliance
            : RouteNames.directorPortfolio;
    context.go(route);
  }
}

class _SchoolHealthCard extends StatelessWidget {
  const _SchoolHealthCard({required this.school});

  final DirectorSchoolRow school;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AksharaSpacing.s4,
          vertical: AksharaSpacing.s2,
        ),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.school_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          school.schoolName,
          style: context.aksharaText.titleSmall,
        ),
        subtitle: Text(
          '${school.location} · ${school.students} students · ${school.revenueCr} Cr',
        ),
        trailing: DirectorSchoolStatusChip(status: school.status),
      ),
    );
  }
}
