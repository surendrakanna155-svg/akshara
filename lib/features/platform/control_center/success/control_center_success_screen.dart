import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../router/route_names.dart';
import '../../../../shared/widgets/akshara_error_state.dart';
import '../../../../shared/widgets/akshara_insight_card.dart';
import '../../../../shared/widgets/akshara_loading_state.dart';
import '../../../../shared/widgets/akshara_section_header.dart';
import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../admin/admin_layout.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';

/// ACC-07 — Customer Success.
class ControlCenterSuccessScreen extends ConsumerWidget {
  const ControlCenterSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(controlCenterSuccessLoadingProvider);
    final isError = ref.watch(controlCenterSuccessErrorProvider);
    final data = ref.watch(controlCenterSuccessProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.success,
      showFilterBar: false,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required ControlCenterSuccessData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading customer success data',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load customer success data.',
      );
    }

    if (data == null) {
      return const AksharaErrorState(
        message: 'Customer success data is not available.',
      );
    }

    final text = context.aksharaText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Customer success'),
        Text(
          '${data.atRiskCount} at risk · Avg adoption ${data.avgAdoptionScore}%',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        if (AdminLayout.useCardLayout(context))
          Column(
            children: [
              for (final school in data.schools) ...[
                _SuccessCard(school: school),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          _SuccessTable(schools: data.schools),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'Assign CS owner',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI churn risk insight',
          onAction: () => context.go(RouteNames.controlCenterCrm),
        ),
      ],
    );
  }
}

class _SuccessTable extends StatelessWidget {
  const _SuccessTable({required this.schools});

  final List<CustomerSuccessSchool> schools;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Customer success table, ${schools.length} schools',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('School')),
              DataColumn(label: Text('Adoption')),
              DataColumn(label: Text('Renewal %')),
              DataColumn(label: Text('Risk')),
              DataColumn(label: Text('CS Owner')),
              DataColumn(label: Text('Low usage')),
            ],
            rows: [
              for (final school in schools)
                DataRow(
                  cells: [
                    DataCell(Text(school.schoolName)),
                    DataCell(Text('${school.adoptionScore}')),
                    DataCell(Text('${school.renewalProbability}%')),
                    DataCell(
                      school.churnRisk
                          ? const AksharaStatusChip(
                              label: 'At risk',
                              tone: KpiAccent.error,
                              semanticLabel: 'Churn risk',
                            )
                          : const AksharaStatusChip(
                              label: 'Healthy',
                              tone: KpiAccent.success,
                              semanticLabel: 'Healthy',
                            ),
                    ),
                    DataCell(Text(school.csOwner)),
                    DataCell(Text(school.lowUsageModules.join(', '))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.school});

  final CustomerSuccessSchool school;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(school.schoolName, style: text.titleSmall),
            Text(
              'Adoption ${school.adoptionScore} · Renewal ${school.renewalProbability}%',
              style: text.bodyMedium,
            ),
            if (school.lowUsageModules.isNotEmpty)
              Text(
                'Low usage: ${school.lowUsageModules.join(', ')}',
                style: text.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
