import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/async/erp_async_state.dart';
import '../../theme/theme_extensions.dart';
import '../phase5/phase5_providers.dart';
import '../../theme/spacing.dart';

class Employee360Screen extends ConsumerWidget {
  const Employee360Screen({super.key, this.employeeId = 'emp_1'});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(employee360Provider(employeeId));
    final dashboard = ref.watch(employeeIntelligenceDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Employee 360')),
      body: ErpAsyncBody(
        state: resolveErpAsync(profile, isDataEmpty: (_) => false),
        loadingLabel: 'Loading profile',
        emptyMessage: 'No employee profile available.',
        onRetry: () => ref.invalidate(employee360Provider(employeeId)),
        builder: (p) {
          return ListView(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            children: [
              ListTile(
                title: Text(p.profile['displayName']?.toString() ?? 'Employee'),
                subtitle: Text(p.profile['department']?.toString() ?? ''),
              ),
              ListTile(
                title: const Text('Workload'),
                subtitle: Text('${p.workload.workloadPercent}% · ${p.workload.burnoutRisk} risk'),
              ),
              ListTile(
                title: const Text('Overload score'),
                trailing: Text('${p.workload.overloadScore}'),
              ),
              ListTile(
                title: const Text('Substitution load'),
                trailing: Text('${p.workload.substitutionLoad}'),
              ),
              const Divider(),
              Text('Insights', style: context.aksharaText.titleMedium),
              ...p.insights.map((i) => ListTile(title: Text(i))),
              const Divider(),
              dashboard.when(
                data: (dash) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('School intelligence', style: context.aksharaText.titleMedium),
                      ListTile(
                        title: const Text('Avg workload'),
                        trailing: Text('${dash.avgWorkloadPercent}%'),
                      ),
                      ...dash.teachersNeedingSupport.map(
                        (t) => ListTile(
                          title: Text(t.name),
                          subtitle: const Text('Needs support'),
                          trailing: Text(t.burnoutRisk ?? ''),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }
}
