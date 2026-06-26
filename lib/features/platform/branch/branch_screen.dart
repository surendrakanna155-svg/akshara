import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import 'branch_mutations_provider.dart';
import 'branch_providers.dart';
import '../../../theme/spacing.dart';

class BranchScreen extends ConsumerWidget {
  const BranchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canViewBranchOperationsProvider)) {
      return const Scaffold(
        body: Center(child: Text('Branch operations permission required.')),
      );
    }
    final dashboard = ref.watch(branchDashboardProvider);
    final assignments = ref.watch(branchAssignmentsProvider);
    return Scaffold(
      key: QaTestKeys.branchScreen,
      appBar: AppBar(title: const Text('Multi-Branch Operations')),
      floatingActionButton: FloatingActionButton.extended(
        key: QaTestKeys.branchAssignSchoolButton,
        onPressed: () => _assignSchool(context, ref),
        icon: const Icon(Icons.link),
        label: const Text('Assign School'),
      ),
      body: dashboard.when(
        loading: () => const AksharaLoadingState(),
        error: (error, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(error),
          onRetry: () => ref.invalidate(branchDashboardProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            Text(
              'Branches: ${data.totalBranches}  •  Schools: ${data.totalSchools}  •  Revenue: INR ${data.totalRevenueLakhs.toStringAsFixed(1)}L',
            ),
            const SizedBox(height: 12),
            ...data.branches.map(
              (branch) => Card(
                child: ListTile(
                  key: QaTestKeys.branchTile(branch.id),
                  title: Text(branch.name),
                  subtitle: Text(
                    '${branch.region} • ${branch.schoolCount} schools • ${branch.activeStudentCount} students',
                  ),
                  trailing:
                      Text('INR ${branch.revenueLakhs.toStringAsFixed(1)}L'),
                  onTap: () {
                    ref.read(selectedBranchIdProvider.notifier).state =
                        branch.id;
                  },
                ),
              ),
            ),
            const Divider(),
            const Text('Assignments', style: TextStyle(fontSize: 16)),
            assignments.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AksharaSpacing.s4),
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => AksharaErrorState.fromFailure(
                apiFailureMapper.fromException(error),
                onRetry: () => ref.invalidate(branchAssignmentsProvider),
              ),
              data: (rows) => Column(
                children: [
                  for (final row in rows)
                    ListTile(
                      key: QaTestKeys.branchAssignmentTile(row.id),
                      title: Text(row.schoolName),
                      subtitle:
                          Text('${row.schoolId} • ${row.assignedManager}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignSchool(BuildContext context, WidgetRef ref) async {
    final assignment =
        await ref.read(branchMutationsProvider.notifier).assignSchool(
              schoolId: 'SCH-NEW-01',
              schoolName: 'New Horizon Campus',
              managerName: 'Ishita Rao',
            );
    if (assignment == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.branchAssignmentSnackbar,
        content: Text('School assigned to branch.'),
      ),
    );
  }
}
