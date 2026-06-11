import 'package:akshara_erp/core/security/phase5_staging_route_manifest.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/server_rbac_route_inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 5 staging readiness', () {
    test('manifest defines all critical Phase 5 routes', () {
      expect(Phase5StagingRouteManifest.routes.length, greaterThanOrEqualTo(10));
      expect(
        Phase5StagingRouteManifest.routes.map((r) => r.$2),
        contains('/parent/experience/hub'),
      );
      expect(
        Phase5StagingRouteManifest.routes.map((r) => r.$2),
        contains('/operations/hub'),
      );
    });

    test('onboarding permissions exist in Permission enum', () {
      expect(Permission.values, contains(Permission.viewOnboarding));
      expect(Permission.values, contains(Permission.manageOnboarding));
    });

    test('server RBAC inventory includes Phase 5 modules', () {
      for (final module in ['operations', 'memories', 'promotion', 'onboarding']) {
        expect(ServerRbacRouteInventory.modules, contains(module));
      }
    });

    test('protected route count reflects v10.4.2 RC inventory', () {
      expect(ServerRbacRouteInventory.protectedRouteCount, greaterThanOrEqualTo(78));
    });
  });
}
