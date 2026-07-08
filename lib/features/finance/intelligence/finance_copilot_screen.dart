import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/widgets.dart';
import '../widgets/finance_module_scaffold.dart';
import '../finance_models.dart';
import 'fee_collection_intelligence.dart';
import 'fee_collection_intelligence_provider.dart';
import 'finance_intelligence_provider.dart';
import '../../../theme/spacing.dart';

/// Finance Copilot — forecasting, defaulter prediction, trend analytics.
class FinanceCopilotScreen extends ConsumerWidget {
  const FinanceCopilotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(financeCopilotProvider);
    final feeIntel = ref.watch(feeCollectionIntelligenceSummaryProvider);

    return FinanceModuleScaffold(
      screen: FinanceScreen.intelligence,
      showFilterBar: false,
      body: ErpAsyncBody(
        state: resolveErpAsync(data, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No finance intelligence available.',
        onRetry: () => ref.invalidate(financeCopilotProvider),
        builder: (snapshot) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            _metric('Fee collection forecast', '₹${snapshot.feeCollectionForecast}'),
            _metric('Confidence', '${snapshot.forecastConfidence}%'),
            _metric('Monthly revenue forecast', '₹${snapshot.monthlyRevenueForecast}'),
            if (snapshot.riskAlerts.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...snapshot.riskAlerts.map(
                (a) => AksharaWarningBanner(message: '${a.title}: ${a.detail}'),
              ),
            ],
            const Divider(height: 32),
            const Text('Collection trend', style: TextStyle(fontWeight: FontWeight.bold)),
            ...snapshot.collectionTrend.map(
              (t) => ListTile(
                title: Text(t.month),
                subtitle: Text('Expected ₹${t.expected}'),
                trailing: Text('₹${t.collected}'),
              ),
            ),
            const Divider(height: 32),
            const Text('Defaulter predictions', style: TextStyle(fontWeight: FontWeight.bold)),
            ...snapshot.defaulterPredictions.map(
              (d) => ListTile(
                title: Text(d.studentName),
                subtitle: Text('Outstanding ₹${d.outstandingAmount} · ${d.daysOverdue}d overdue'),
                trailing: Text('Risk ${d.riskScore}'),
              ),
            ),
            feeIntel.when(
              data: (summary) => _feeCollectionIntelligenceSection(summary),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _feeCollectionIntelligenceSection(FeeCollectionIntelligenceSummary summary) {
  if (summary.topProfiles.isEmpty && summary.alertActions.isEmpty) {
    return const SizedBox.shrink();
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 32),
      const Text('Fee collection intelligence', style: TextStyle(fontWeight: FontWeight.bold)),
      ListTile(
        title: const Text('Collection gap'),
        trailing: Text('${summary.collectionGapPercent}%'),
      ),
      ListTile(
        title: const Text('Flagged defaulters'),
        trailing: Text('${summary.totalFlagged}'),
      ),
      ListTile(
        title: const Text('Total outstanding (flagged)'),
        trailing: Text('₹${summary.totalOutstanding}'),
      ),
      for (final profile in summary.topProfiles)
        ListTile(
          title: Text('${profile.studentName} · ${profile.tier.label}'),
          subtitle: Text(
            '${profile.className} · ₹${profile.outstandingAmount}\n${profile.recommendedAction}',
          ),
          isThreeLine: true,
        ),
      for (final alert in summary.alertActions)
        AksharaWarningBanner(message: alert),
    ],
  );
}

Widget _metric(String label, String value) {
  return ListTile(
    title: Text(label),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
  );
}
