import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/inventory_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// Inventory procurement PO approve + receive chain (mock mode).
void main() {
  patrolTest(
    'journey: inventory approve PO handoff E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.inventoryProcurement);
      await assertVisibleText($, 'Purchase orders');
      await approveInventoryProcurementOrder($, orderId: 'po_4');
    },
  );
}
