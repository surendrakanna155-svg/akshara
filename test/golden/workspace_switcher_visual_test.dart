import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/admin/screens/admin_hub_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// Visual validation of the multi-role workspace switcher on the Admin Hub:
/// a Teacher + Inventory user sees the switcher (app-bar button + inline chips)
/// and the premium module cards. Run with --update-goldens to (re)generate.
void main() {
  testWidgets('visual: multi-hat admin hub shows workspace switcher', (
    tester,
  ) async {
    await pumpGoldenErpScreen(
      tester,
      screen: const AdminHubScreen(),
      viewport: GoldenViewports.tablet834,
      extraOverrides: [
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRoles(
            const [ErpRole.inventoryManager, ErpRole.teacher],
          ),
        ),
      ],
    );

    await expectLater(
      find.byType(AdminHubScreen),
      matchesGoldenFile('goldens/workspace_switcher_multihat_834x1194.png'),
    );
  });
}
