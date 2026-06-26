import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_failure_mapper.dart';
import '../../router/phase5_navigation.dart';
import '../../shared/widgets/akshara_error_state.dart';
import '../../shared/widgets/akshara_loading_state.dart';
import '../../theme/theme_extensions.dart';
import '../phase4/phase4_providers.dart';
import '../../theme/spacing.dart';

class EmployeePlatformScreen extends ConsumerWidget {
  const EmployeePlatformScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(employeeDashboardProvider);
    final employees = ref.watch(employeesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Employee Platform')),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
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
            loading: () => const AksharaLoadingState(semanticLabel: 'Loading dashboard'),
            error: (e, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(e),
              onRetry: () => ref.invalidate(employeeDashboardProvider),
            ),
          ),
          const SizedBox(height: 16),
          Text('Employees', style: context.aksharaText.titleMedium),
          employees.when(
            data: (items) => Column(
              children: items
                  .map(
                    (e) => ListTile(
                      title: Text(e.displayName),
                      subtitle: Text('${e.employeeCode} · ${e.status}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(employee360Path(e.id)),
                    ),
                  )
                  .toList(),
            ),
            loading: () => const AksharaLoadingState(semanticLabel: 'Loading employees'),
            error: (e, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(e),
              onRetry: () => ref.invalidate(employeesListProvider),
            ),
          ),
        ],
      ),
    );
  }
}
