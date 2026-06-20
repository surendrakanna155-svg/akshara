import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX Batch 1, Step 3 — persona-leak regression guard.
/// School roles must NOT hold non-school vertical / platform / white-label
/// permissions. superAdmin remains the platform / multi-industry owner.
void main() {
  const verticalPerms = <Permission>[
    Permission.viewSalonBusiness,
    Permission.viewRestaurantHospitality,
    Permission.viewHealthcare,
    Permission.viewAccommodation,
    Permission.viewWhiteLabelPlatform,
    Permission.viewIndustryFramework,
    Permission.viewPlatformOperations,
  ];

  for (final role in [ErpRole.schoolAdmin, ErpRole.management, ErpRole.principal]) {
    test('$role holds no non-school vertical/platform permissions', () {
      final perms = UserPermissions.forRole(role);
      for (final p in verticalPerms) {
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
}
