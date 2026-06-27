import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/platform/branch/branch_mutations_provider.dart';
import 'package:akshara_erp/features/platform/white_label/white_label_models.dart';
import 'package:akshara_erp/features/platform/white_label/white_label_mutations_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// SA-2 (MJ-L5): mock-backed super-admin platform write actions must NOT
/// fabricate success in a live build. When the module has no live backend
/// (always-mock, or its API flag is off) the write must surface an honest
/// [ApiFailureType.notConnected] state instead of a fake success.
void main() {
  // A super-admin session that still *holds* the manage permission (simulating
  // the offline local-matrix fallback) so we isolate the SA-2 backend guard
  // from the SA-1 permission removal.
  UserPermissions managePerms(Permission permission) => UserPermissions(
        role: ErpRole.superAdmin,
        permissionSet: PermissionSet.from([permission]),
      );

  ProviderContainer buildContainer({
    required bool liveBuild,
    required Permission permission,
    List<Override> extra = const [],
  }) {
    final perms = managePerms(permission);
    return ProviderContainer(
      overrides: [
        if (liveBuild)
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: true),
          ),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        userPermissionsProvider.overrideWithValue(perms),
        rbacServiceProvider.overrideWithValue(RbacService(perms)),
        ...extra,
      ],
    );
  }

  group('platform backend guard (SA-2)', () {
    test(
        'branch assignSchool surfaces notConnected in a live build '
        '(always mock-backed)', () async {
      final container = buildContainer(
        liveBuild: true,
        permission: Permission.manageBranchOperations,
      );
      addTearDown(container.dispose);

      final result =
          await container.read(branchMutationsProvider.notifier).assignSchool(
                schoolId: 'sch_1',
                schoolName: 'Demo School',
                managerName: 'Asha',
              );

      // No fabricated success value.
      expect(result, isNull);
      final state = container.read(branchMutationsProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<ApiFailureException>());
      expect(
        (state.error as ApiFailureException).failure.type,
        ApiFailureType.notConnected,
      );
    });

    test(
        'white-label saveBrandingProfile surfaces notConnected in a live build '
        '(API flag off)', () async {
      final container = buildContainer(
        liveBuild: true,
        permission: Permission.manageWhiteLabelPlatform,
      );
      addTearDown(container.dispose);

      const profile = BrandingProfile(
        id: 'bp_1',
        name: 'Acme',
        primaryColor: '#000000',
        accentColor: '#ffffff',
        isDefault: false,
      );

      final result = await container
          .read(saveBrandingProfileProvider.notifier)
          .execute(profile: profile);

      expect(result, isNull);
      final state = container.read(saveBrandingProfileProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<ApiFailureException>());
      expect(
        (state.error as ApiFailureException).failure.type,
        ApiFailureType.notConnected,
      );
    });

    test(
        'local (non-API) build still allows the mock write '
        '(mock fallback is intended offline)', () async {
      final container = buildContainer(
        liveBuild: false,
        permission: Permission.manageBranchOperations,
      );
      addTearDown(container.dispose);

      final result =
          await container.read(branchMutationsProvider.notifier).assignSchool(
                schoolId: 'sch_1',
                schoolName: 'Demo School',
                managerName: 'Asha',
              );

      expect(result, isNotNull);
      expect(container.read(branchMutationsProvider).hasError, isFalse);
    });
  });
}
