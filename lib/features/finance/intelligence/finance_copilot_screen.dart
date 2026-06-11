import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../widgets/finance_module_scaffold.dart';
import '../finance_models.dart';
import 'finance_intelligence_provider.dart';

/// Finance Copilot — forecasting, defaulter prediction, trend analytics.
class FinanceCopilotScreen extends ConsumerWidget {
  const FinanceCopilotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(financeCopilotProvider);

    return FinanceModuleScaffold(
      screen: FinanceScreen.intelligence,
      showFilterBar: false,
      body: data.when(
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState(message: '$e'),
        data: (snapshot) => ListView(
          padding: const EdgeInsets.all(16),
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
          ],
        ),
      ),
    );
  }
}

Widget _metric(String label, String value) {
  return ListTile(
    title: Text(label),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
  );
}
