import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW5 · QA-J-055 — Super Admin · acknowledge/triage platform alert. **PARTIAL.**
///
/// The client wiring is real (`platform_operations_mutations_provider` →
/// `acknowledgeAlert`, gated `managePlatformOperations` in the registry), but the
/// LIVE round-trip is **infra-blocked**: the `managePlatformOperations` permission
/// was intentionally REMOVED from every role and the platform-operations backend
/// is **unseeded server-side** (per `role_permissions.dart` SA-1/MJ-L5:
/// "GET /platform-operations/observability is 404 live"). So the acknowledge
/// persistence + state-change round-trip cannot be proven without a seeded
/// platform-ops backend (a live-regression lane) — this is NOT forced to Verified.
///
/// What IS locally verifiable, and asserted here: (1) the acknowledge mutation's
/// gate CONTRACT, and (2) that the gate is currently held by NO standard role,
/// which pins the "unseeded / removed" reality so it cannot silently regress.
UserPermissions _role(ErpRole r) => UserPermissions.forRole(r);

Permission _gate(String module, String mutationId) =>
    MutationPermissionRegistry.forModule(module)
        .firstWhere((e) => e.mutationId == mutationId)
        .permission;

void main() {
  group('QW5 · QA-J-055 platform alert acknowledge (PARTIAL)', () {
    test('acknowledgeAlert is gated by managePlatformOperations (the contract)',
        () {
      expect(
        _gate('platform_operations', 'acknowledgeAlert'),
        Permission.managePlatformOperations,
      );
    });

    test('the platform-ops gate is currently unseeded — held by no standard '
        'role (documents the infra-blocked live round-trip)', () {
      // SA-1/MJ-L5: platform-operations permissions removed (server-side 404).
      for (final role in ErpRole.values) {
        expect(
          _role(role).has(Permission.managePlatformOperations),
          isFalse,
          reason: '${role.name} must NOT hold the unseeded platform-ops gate',
        );
      }
    });
  });
}
