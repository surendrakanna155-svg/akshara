import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX Batch 1, Step 3 — persona-leak regression guard.
/// School roles must NOT hold non-school vertical / platform / white-label
/// permissions. superAdmin remains the platform / multi-industry owner.
void main() {
  // Vertical-pack permissions superAdmin owns (industry packs are seeded /
  // in scope for superAdmin).
  const verticalPerms = <Permission>[
    Permission.viewSalonBusiness,
    Permission.viewRestaurantHospitality,
    Permission.viewHealthcare,
    Permission.viewAccommodation,
    Permission.viewIndustryFramework,
  ];

  // SA-1 (MJ-L5): platform-ops / white-label permissions are NOT seeded in any
  // server migration, so superAdmin must NOT hold them either (client/server
  // drift fix). They remain forbidden for school roles too.
  const unseededPlatformPerms = <Permission>[
    Permission.viewWhiteLabelPlatform,
    Permission.viewPlatformOperations,
  ];

  for (final role in [ErpRole.schoolAdmin, ErpRole.management, ErpRole.principal]) {
    test('$role holds no non-school vertical/platform permissions', () {
      final perms = UserPermissions.forRole(role);
      for (final p in [...verticalPerms, ...unseededPlatformPerms]) {
        expect(perms.has(p), isFalse, reason: '$role should not have $p');
      }
    });
  }

  test('superAdmin remains the platform/vertical owner', () {
    final perms = UserPermissions.forRole(ErpRole.superAdmin);
    for (final p in verticalPerms) {
      expect(perms.has(p), isTrue, reason: 'superAdmin should retain $p');
    }
  });

  test('superAdmin does not hold unseeded platform permissions (SA-1)', () {
    final perms = UserPermissions.forRole(ErpRole.superAdmin);
    for (final p in unseededPlatformPerms) {
      expect(perms.has(p), isFalse,
          reason: 'superAdmin should NOT advertise unseeded $p');
    }
  });
}
