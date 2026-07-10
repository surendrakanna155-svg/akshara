import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../copilot/copilot_models.dart';
import '../../copilot/copilot_provider.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_executive_kpi_card.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';

/// N10 — AI Usage & Cost panel: this school's month-to-date AI spend vs cap,
/// model calls vs governed fallbacks, and cache reuse savings. Reads the
/// backend GET /copilot/economics (RBAC viewAiCopilot) via
/// [copilotEconomicsFutureProvider]; the copilot Hybrid/Mock split renders
/// deterministic sample data until the backend flag is live.
class AiEconomicsScreen extends ConsumerWidget {
  const AiEconomicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Defense-in-depth: the Hub tile is RBAC-gated, but the screen re-checks
    // like CopilotScreen so a direct push or a stale client cache never shows
    // an unauthorized user a healthy-looking cost panel.
    if (!ref.watch(copilotCanUseProvider)) {
      return const Scaffold(
        body: AksharaErrorState(
          message: 'AI Copilot is not enabled for your role.',
          icon: Icons.lock_outline,
        ),
      );
    }

    final economicsAsync = ref.watch(copilotEconomicsFutureProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Usage & Cost')),
      body: ErpAsyncBody(
        // A single-object payload is never "empty" — zeros are real data, so
        // the empty state (and its message) is deliberately unreachable.
        state: resolveErpAsync(economicsAsync, isDataEmpty: (_) => false),
        loadingLabel: 'Loading AI usage & cost',
        emptyMessage: 'No AI usage recorded yet this month.',
        onRetry: () => ref.invalidate(copilotEconomicsFutureProvider),
        builder: (economics) => _AiEconomicsBody(economics: economics),
      ),
    );
  }
}

class _AiEconomicsBody extends StatelessWidget {
  const _AiEconomicsBody({required this.economics});

  final AiEconomics economics;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final capped = economics.spendCapMicros > 0;
    final ratio = economics.spendRatio.clamp(0.0, 1.0);

    final accent = economics.atSpendCap
        ? KpiAccent.error
        : economics.atSpendWarn
            ? KpiAccent.warning
            : KpiAccent.success;
    final accentColor = accent.resolve(context).foreground;
    final chipLabel = economics.atSpendCap
        ? 'At cap'
        : economics.atSpendWarn
            ? 'Near cap'
            : 'On track';

    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        const AksharaSectionHeader(
          title: 'Month-to-date spend',
          fixedHeight: false,
        ),
        const SizedBox(height: AksharaSpacing.s2),
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AksharaRadius.card,
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        capped
                            ? '${_formatUsd(economics.spendMicros)} of ${_formatUsd(economics.spendCapMicros)}'
                            : _formatUsd(economics.spendMicros),
                        style: text.titleMedium,
                      ),
                    ),
                    AksharaStatusChip(label: chipLabel, tone: accent),
                  ],
                ),
                if (capped) ...[
                  const SizedBox(height: AksharaSpacing.s2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AksharaRadius.xs),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: colors.surfaceContainerHighest,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(
                    // The bar clamps at 100%, the label never lies: overspend
                    // shows its true magnitude (e.g. 120%).
                    '${(economics.spendRatio * 100).round()}% of the monthly cap · warns at '
                    '${(economics.spendWarnRatio * 100).round()}%',
                    style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  ),
                ] else ...[
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(
                    'No monthly spend cap configured.',
                    style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Model calls', fixedHeight: false),
        const SizedBox(height: AksharaSpacing.s2),
        Wrap(
          spacing: AksharaSpacing.s3,
          runSpacing: AksharaSpacing.s3,
          children: [
            AksharaExecutiveKpiCard(
              label: 'Real model calls',
              value: '${economics.modelCalls}',
              accent: KpiAccent.indigo,
              icon: Icons.bolt_outlined,
            ),
            AksharaExecutiveKpiCard(
              label: 'Governed fallbacks',
              value: '${economics.fallbacks}',
              accent: KpiAccent.neutral,
              icon: Icons.shield_outlined,
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Cache reuse', fixedHeight: false),
        const SizedBox(height: AksharaSpacing.s2),
        Wrap(
          spacing: AksharaSpacing.s3,
          runSpacing: AksharaSpacing.s3,
          children: [
            AksharaExecutiveKpiCard(
              label: 'Cache hit ratio',
              value: '${(economics.cacheHitRatio * 100).round()}%',
              accent: KpiAccent.success,
              icon: Icons.cached_outlined,
            ),
            AksharaExecutiveKpiCard(
              label: 'Tokens saved',
              value: '${economics.tokensSaved}',
              accent: KpiAccent.tertiary,
              icon: Icons.savings_outlined,
            ),
            AksharaExecutiveKpiCard(
              label: 'Live cache entries',
              value: '${economics.cacheEntries}',
              accent: KpiAccent.primary,
              icon: Icons.storage_outlined,
            ),
          ],
        ),
        if (economics.callsByOutcome.isNotEmpty) ...[
          const SizedBox(height: AksharaSpacing.s6),
          const AksharaSectionHeader(title: 'Calls by outcome', fixedHeight: false),
          const SizedBox(height: AksharaSpacing.s2),
          for (final entry in economics.callsByOutcome.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
              child: Material(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AksharaRadius.card,
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: ListTile(
                  title: Text(_surfaceLabel(entry.key)),
                  trailing: Text('${entry.value}', style: text.titleSmall),
                ),
              ),
            ),
        ],
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Calls by surface', fixedHeight: false),
        const SizedBox(height: AksharaSpacing.s2),
        if (economics.callsBySurface.isEmpty)
          Text(
            'No AI calls recorded yet this month.',
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          )
        else
          for (final entry in economics.callsBySurface.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
              child: Material(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AksharaRadius.card,
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: ListTile(
                  title: Text(_surfaceLabel(entry.key)),
                  trailing: Text('${entry.value}', style: text.titleSmall),
                ),
              ),
            ),
      ],
    );
  }

  /// Micros of USD → "US$X.XX" (the gateway spend cap is USD, not INR).
  String _formatUsd(int micros) => 'US\$${(micros / 1000000).toStringAsFixed(2)}';

  String _surfaceLabel(String key) {
    return key
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
