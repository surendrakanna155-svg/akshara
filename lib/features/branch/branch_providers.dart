import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'branch_models.dart';

final canViewBranchOperationsProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.viewBranchOperations);
});

final canManageBranchOperationsProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.manageBranchOperations);
});

final branchDashboardProvider = FutureProvider<BranchDashboard>((ref) async {
  return ref.read(branchRepositoryProvider).getDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final selectedBranchIdProvider = StateProvider<String>((ref) => 'BR-01');

final branchAssignmentsProvider =
    FutureProvider<List<BranchAssignment>>((ref) async {
  return ref.read(branchRepositoryProvider).listAssignments(
        query: ref.watch(repositoryQueryProvider),
        branchId: ref.watch(selectedBranchIdProvider),
      );
});
