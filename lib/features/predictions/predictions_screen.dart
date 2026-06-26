import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlement_models.dart';
import '../../core/entitlements/entitlement_provider.dart';
import '../../core/repositories/repository_config.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../entitlements/entitlement_module_gate.dart';
import 'predictions_models.dart';
import 'predictions_providers.dart';
import '../../core/errors/api_failure_mapper.dart';

/// Advanced AI Predictions (B9) — a single school-leadership surface with three
/// real, data-grounded prediction feeds (fee-default, admission-conversion,
/// student-risk), each with an optional AI narrative. Gated by the
/// `feature.ai_predictions` entitlement (Enterprise / per-deal override); the
/// server also enforces the gate (402) and per-domain RBAC.
class PredictionsScreen extends ConsumerWidget {
  const PredictionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Client-side entitlement gate (defense-in-depth; mirrors the marketing gate).
    final entitlementOn = ref.watch(entitlementApiEnabledProvider);
    final allowed =
        !entitlementOn || ref.watch(subscriptionProvider).allows(EntitlementSlugs.aiPredictions);
    if (!allowed) {
      return const PlanLockedModuleView(moduleLabel: 'AI Predictions');
    }

    final canViewFee = ref.watch(predictionsCanViewFeeDefaultProvider);
    final canViewConversion = ref.watch(predictionsCanViewConversionProvider);
    final canViewRisk = ref.watch(predictionsCanViewStudentRiskProvider);

    return Scaffold(
      key: QaTestKeys.predictionsScreen,
      appBar: AppBar(title: const Text('AI Predictions')),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Text(
            'Forward-looking risk and likelihood scores, computed from your live '
            'school data. Act on the highest-priority items first.',
            style: context.aksharaText.bodyMedium,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          if (canViewFee)
            _FeeDefaultSection()
          else
            const SizedBox.shrink(),
          if (canViewConversion) ...[
            const SizedBox(height: AksharaSpacing.s5),
            _ConversionSection(),
          ],
          if (canViewRisk) ...[
            const SizedBox(height: AksharaSpacing.s5),
            _StudentRiskSection(),
          ],
          if (!canViewFee && !canViewConversion && !canViewRisk)
            const AksharaEmptyState(
              message: 'You do not have access to any prediction feeds.',
            ),
        ],
      ),
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.narrative});

  final String narrative;

  @override
  Widget build(BuildContext context) {
    if (narrative.trim().isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AksharaSpacing.s3),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AksharaSpacing.s2),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 18, color: colors.primary),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(child: Text(narrative)),
        ],
      ),
    );
  }
}

KpiAccent _riskTone(PredictionRiskLevel level) => switch (level) {
      PredictionRiskLevel.critical => KpiAccent.error,
      PredictionRiskLevel.high => KpiAccent.error,
      PredictionRiskLevel.medium => KpiAccent.warning,
      PredictionRiskLevel.low => KpiAccent.success,
    };

String _riskLabel(PredictionRiskLevel level) => switch (level) {
      PredictionRiskLevel.critical => 'Critical',
      PredictionRiskLevel.high => 'High',
      PredictionRiskLevel.medium => 'Medium',
      PredictionRiskLevel.low => 'Low',
    };

class _FeeDefaultSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feeDefaultPredictionsProvider);
    return Column(
      key: QaTestKeys.predictionsFeeDefaultSection,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Fee-default risk'),
        const SizedBox(height: AksharaSpacing.s2),
        state.when(
          loading: () => const AksharaLoadingState(),
          error: (e, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)),
          data: (feed) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NarrativeCard(narrative: feed.narrative),
              const SizedBox(height: AksharaSpacing.s2),
              if (feed.items.isEmpty)
                const AksharaEmptyState(message: 'No outstanding fee risk detected.')
              else
                for (final p in feed.items)
                  Card(
                    child: ListTile(
                      title: Text('${p.studentName} · ${p.className}'),
                      subtitle: Text(
                        '₹${p.outstandingInr} outstanding · ${p.daysOverdue} days overdue',
                      ),
                      trailing: AksharaStatusChip(
                        label: '${_riskLabel(p.riskLevel)} ${p.riskScore}',
                        tone: _riskTone(p.riskLevel),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConversionSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(admissionConversionPredictionsProvider);
    KpiAccent tone(ConversionBand b) => switch (b) {
          ConversionBand.hot => KpiAccent.success,
          ConversionBand.warm => KpiAccent.warning,
          ConversionBand.cool => KpiAccent.neutral,
        };
    String label(ConversionBand b) => switch (b) {
          ConversionBand.hot => 'Hot',
          ConversionBand.warm => 'Warm',
          ConversionBand.cool => 'Cool',
        };
    return Column(
      key: QaTestKeys.predictionsConversionSection,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Admission conversion likelihood'),
        const SizedBox(height: AksharaSpacing.s2),
        state.when(
          loading: () => const AksharaLoadingState(),
          error: (e, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)),
          data: (feed) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NarrativeCard(narrative: feed.narrative),
              const SizedBox(height: AksharaSpacing.s2),
              if (feed.items.isEmpty)
                const AksharaEmptyState(message: 'No open admission leads to score.')
              else
                for (final p in feed.items)
                  Card(
                    child: ListTile(
                      title: Text('${p.studentName} · ${p.classLabel}'),
                      subtitle: Text('Source: ${p.source} · ${p.ageDays} days old'),
                      trailing: AksharaStatusChip(
                        label: '${label(p.band)} ${p.likelihood}%',
                        tone: tone(p.band),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentRiskSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentRiskPredictionsProvider);
    return Column(
      key: QaTestKeys.predictionsStudentRiskSection,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Student academic risk'),
        const SizedBox(height: AksharaSpacing.s2),
        state.when(
          loading: () => const AksharaLoadingState(),
          error: (e, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)),
          data: (feed) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NarrativeCard(narrative: feed.narrative),
              const SizedBox(height: AksharaSpacing.s2),
              if (feed.items.isEmpty)
                const AksharaEmptyState(message: 'No student risk signals detected.')
              else
                for (final p in feed.items)
                  Card(
                    child: ListTile(
                      title: Text('${p.studentName} · ${p.className}'),
                      subtitle: Text(p.topReason),
                      trailing: AksharaStatusChip(
                        label: '${_riskLabel(p.riskLevel)} ${p.riskScore}',
                        tone: _riskTone(p.riskLevel),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
