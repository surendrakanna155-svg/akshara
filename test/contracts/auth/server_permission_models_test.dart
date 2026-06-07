import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/server_permission_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('effective permissions exclude revoked grants', () {
    final policy = ServerPermissionPolicy(
      version: 1,
      syncedAt: DateTime.now(),
      grants: [
        PermissionGrant(
          permission: Permission.viewAdmissions,
          grantedAt: DateTime.now(),
        ),
        PermissionGrant(
          permission: Permission.viewFinance,
          grantedAt: DateTime.now(),
        ),
      ],
      revocations: [
        PermissionRevocation(
          permission: Permission.viewFinance,
          revokedAt: DateTime.now(),
        ),
      ],
    );

    expect(policy.effectivePermissions, {Permission.viewAdmissions});
  });
}
