import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'auth: switchQaPersona finance to principal',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await assertVisibleText($, 'Fee Collected (MTD)');
      await switchQaPersona($, QaLoginPersona.principal);
      await assertVisibleText($, 'Principal overview');
    },
  );

  patrolTest(
    'auth: switchQaPersona parent to principal',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleText($, 'Fees');
      await switchQaPersona($, QaLoginPersona.principal);
      await assertVisibleText($, 'Principal overview');
    },
  );
}
