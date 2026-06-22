import 'package:akshara_erp/core/config/chain_scope.dart';
import 'package:akshara_erp/features/admin/models/admin_nav_models.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_test_overrides.dart';

void main() {
  group('ChainScope.isChainOnlyRoute (M3 chain gate)', () {
    test('franchise / multi-school / org-builder routes are chain-only', () {
      for (final route in [
        RouteNames.franchise,
        RouteNames.multiSchoolPortfolio,
        RouteNames.multiSchoolOnboarding,
        RouteNames.organizationBuilder,
        RouteNames.organizationBuilderInterview, // nested sub-route
        RouteNames.organizationBuilderProvisioning,
        RouteNames.schoolDiscovery,
        '${RouteNames.franchise}/anything', // arbitrary sub-route
      ]) {
        expect(
          ChainScope.isChainOnlyRoute(route),
          isTrue,
          reason: '$route must be chain-gated',
        );
      }
    });

    test('kept (non-chain) routes are NOT chain-only', () {
      for (final route in [
        RouteNames.financeDashboard,
        RouteNames.controlCenterDashboard,
        RouteNames.directorDashboard,
        RouteNames.branches, // branch mgmt is kept, not chain-gated
        RouteNames.whiteLabel, // SaaS tier, gated by SchoolBuildScope instead
        RouteNames.platformOperations,
        RouteNames.admin,
      ]) {
        expect(
          ChainScope.isChainOnlyRoute(route),
          isFalse,
          reason: '$route must not be chain-gated',
        );
      }
    });
  });

  group('ChainScope.isChainOnlyModule', () {
    test('organization-builder is chain-only; others are not', () {
      expect(ChainScope.isChainOnlyModule(AdminModule.organizationBuilder),
          isTrue);
      for (final module in [
        AdminModule.finance,
        AdminModule.controlCenter,
        AdminModule.whiteLabel,
        AdminModule.director,
        AdminModule.admin,
      ]) {
        expect(ChainScope.isChainOnlyModule(module), isFalse);
      }
    });
  });

  group('isChainOrgProvider', () {
    test('defaults to false when unauthenticated', () {
      final container = ProviderContainer(
        overrides: [
          authStateOverride(const AuthState(status: AuthStatus.unauthenticated)),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(isChainOrgProvider), isFalse);
    });

    test('false for a single independent school (default claims)', () {
      final container = ProviderContainer(
        overrides: [
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9876543210',
              displayName: 'Principal',
              role: UserRole.staff,
              claims: AuthClaims.demoForRole(erpRole: ErpRole.principal),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(isChainOrgProvider), isFalse);
    });

    test('true when the org claims chain status', () {
      final container = ProviderContainer(
        overrides: [
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9876543210',
              displayName: 'Chain Admin',
              role: UserRole.staff,
              claims: AuthClaims.demoForRole(
                erpRole: ErpRole.principal,
                isChainOrganization: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(isChainOrgProvider), isTrue);
    });
  });
}
