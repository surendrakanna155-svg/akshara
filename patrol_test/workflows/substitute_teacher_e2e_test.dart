import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter/foundation.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: assign substitute teacher',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.substituteManager);

      await $('Substitute Teacher Wizard').waitUntilVisible();
      await $(const ValueKey('substitute_slot_slot_1')).tap();
      await $(const ValueKey('substitute_teacher_teacher_2')).tap();
      await $(QaTestKeys.substituteAssignButton).tap();

      await assertVisibleKey($, QaTestKeys.substituteAssignSuccessSnackbar);
    },
  );
}
