import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../widgets/finance_module_scaffold.dart';
import '../finance_models.dart';
import 'finance_intelligence_provider.dart';

/// Finance Executive Dashboard — collection health and risk students.
class FinanceExecutiveDashboardScreen extends ConsumerWidget {
  const FinanceExecutiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(financeExecutiveProvider);

    return FinanceModuleScaffold(
      screen: FinanceScreen.executiveDashboard,
      showFilterBar: false,
      body: data.when(
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState(message: '$e'),
        data: (snapshot) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: const Text('Collection health score'),
              trailing: Text(
                '${snapshot.collectionHealthScore}/100',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            ListTile(
              title: const Text('Expected collections'),
              trailing: Text('₹${snapshot.expectedCollections}'),
            ),
            ListTile(
              title: const Text('Outstanding collections'),
              trailing: Text('₹${snapshot.outstandingCollections}'),
            ),
            if (snapshot.collectionHealthScore < 70)
              const AksharaWarningBanner(
                message: 'Collection health below target — review defaulter follow-ups',
              ),
            const Divider(height: 32),
            const Text('Risk students', style: TextStyle(fontWeight: FontWeight.bold)),
            ...snapshot.riskStudents.map(
              (s) => ListTile(
                title: Text(s.studentName),
                subtitle: Text('₹${s.outstandingAmount} outstanding'),
                trailing: Text('${s.riskScore}%'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
