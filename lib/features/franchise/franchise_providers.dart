import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'franchise_models.dart';

final canViewFranchiseOperationsProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.viewFranchiseOperations);
});

final canManageFranchiseOperationsProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.manageFranchiseOperations);
});

final franchiseDashboardProvider =
    FutureProvider<FranchiseDashboard>((ref) async {
  return ref.read(franchiseRepositoryProvider).getDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});
