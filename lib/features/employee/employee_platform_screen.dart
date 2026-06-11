import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../phase4/phase4_providers.dart';

class EmployeePlatformScreen extends ConsumerWidget {
  const EmployeePlatformScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(employeeDashboardProvider);
    final employees = ref.watch(employeesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Employee Platform')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          dashboard.when(
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(title: const Text('Total employees'), trailing: Text('${d.totalEmployees}')),
                ListTile(title: const Text('Active'), trailing: Text('${d.activeEmployees}')),
                ListTile(title: const Text('Workload index'), trailing: Text('${d.workloadIndex}')),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          const SizedBox(height: 16),
          Text('Employees', style: Theme.of(context).textTheme.titleMedium),
          employees.when(
            data: (items) => Column(
              children: items
                  .map(
                    (e) => ListTile(
                      title: Text(e.displayName),
                      subtitle: Text('${e.employeeCode} · ${e.status}'),
                    ),
                  )
                  .toList(),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }
}
