import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../copilot/copilot_context_provider.dart';
import '../../copilot/copilot_models.dart';
import '../../copilot/copilot_provider.dart';
import '../../copilot/copilot_role_intelligence.dart';
import '../director_models.dart';

class DirectorKpiRow extends StatelessWidget {
  const DirectorKpiRow({super.key, required this.kpis});

  final List<DirectorKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AksharaSpacing.s3,
      runSpacing: AksharaSpacing.s3,
      children: [
        for (final kpi in kpis)
          SizedBox(
            width: 240,
            height: 132,
            child: AksharaKpiCard(
              value: kpi.value,
              subtitle: kpi.label,
              icon: kpi.icon,
              detail: kpi.detail,
              accent: KpiAccent.primary,
              style: AksharaKpiCardStyle.filled,
            ),
          ),
      ],
    );
  }
}

class DirectorSchoolStatusChip extends StatelessWidget {
  const DirectorSchoolStatusChip({super.key, required this.status});

  final DirectorSchoolStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      DirectorSchoolStatus.topPerformer => ('Top Performer', KpiAccent.success),
      DirectorSchoolStatus.onTrack => ('On Track', KpiAccent.primary),
      DirectorSchoolStatus.atRisk => ('At Risk', KpiAccent.warning),
      DirectorSchoolStatus.critical => ('Critical', KpiAccent.error),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class DirectorComplianceStatusChip extends StatelessWidget {
  const DirectorComplianceStatusChip({super.key, required this.status});

  final DirectorComplianceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      DirectorComplianceStatus.compliant => ('Compliant', KpiAccent.success),
      DirectorComplianceStatus.dueSoon => ('Due Soon', KpiAccent.warning),
      DirectorComplianceStatus.overdue => ('Overdue', KpiAccent.error),
      DirectorComplianceStatus.notApplicable => (
          'Not Applicable',
          KpiAccent.neutral
        ),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class DirectorAiAssistantLink extends ConsumerWidget {
  const DirectorAiAssistantLink({
    super.key,
    required this.screenLabel,
    this.buttonKey,
  });

  final String screenLabel;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      key: buttonKey,
      onPressed: () => _openDirectorCopilot(context, ref),
      icon: const Icon(Icons.smart_toy_outlined, size: 18),
      label: const Text('Director AI Assistant'),
    );
  }

  void _openDirectorCopilot(BuildContext context, WidgetRef ref) {
    final origin = GoRouterState.of(context).uri.path;
    final base = buildCopilotScreenContext(
      ref,
      originRoute: origin,
      screen: screenLabel,
    );
    ref.read(copilotPendingNavigationContextProvider.notifier).state =
        base.copyWith(
      personaRole: CopilotPersonaRole.directorCorrespondent,
      module: 'director',
      suggestedAssistant: CopilotAssistantType.principal,
    );
    ref.read(copilotSelectedAssistantProvider.notifier).state =
        CopilotAssistantType.principal;
    context.go(RouteNames.copilot);
  }
}

class DirectorMetricTile extends StatelessWidget {
  const DirectorMetricTile({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.bodySmall),
            const SizedBox(height: AksharaSpacing.s1),
            Text(value, style: text.titleMedium),
          ],
        ),
      ),
    );
  }
}

class DirectorExecutiveSummaryCard extends StatelessWidget {
  const DirectorExecutiveSummaryCard({
    super.key,
    required this.summary,
  });

  final String summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    return Container(
      key: QaTestKeys.directorExecutiveSummaryCard,
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: colors.primary, size: 20),
              const SizedBox(width: AksharaSpacing.s2),
              Text(
                'Executive summary',
                style: text.titleMedium.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
          Text(
            summary,
            style: text.bodyMedium.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
