import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../phase5/phase5_providers.dart';

class Employee360Screen extends ConsumerWidget {
  const Employee360Screen({super.key, this.employeeId = 'emp_1'});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(employee360Provider(employeeId));
    final dashboard = ref.watch(employeeIntelligenceDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Employee 360')),
      body: profile.when(
        data: (p) {
          return ListView(
            padding: const EdgeInsets.all(16),
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
              Text('Insights', style: Theme.of(context).textTheme.titleMedium),
              ...p.insights.map((i) => ListTile(title: Text(i))),
              const Divider(),
              dashboard.when(
                data: (dash) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('School intelligence', style: Theme.of(context).textTheme.titleMedium),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
