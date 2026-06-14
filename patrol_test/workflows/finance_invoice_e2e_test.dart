import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/finance_invoice_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: finance invoice issue cancel and collection cancel E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.financeFeeAssignment);
      await assertVisibleText($, 'Admissions handoff queue');

      await issueDraftInvoice($, 'inv_3');
      await cancelOpenInvoice($, 'inv_3');

      await goToErpRoute($, RouteNames.financeCollectionDetail('col_1'));
      await assertVisibleText($, 'RCP-2026-8841');
      await cancelCollectionRecord($, 'col_1');
    },
  );
}
