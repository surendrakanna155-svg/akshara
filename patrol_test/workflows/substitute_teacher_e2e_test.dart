import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      await tapByKey($, const ValueKey('substitute_slot_slot_1'), scrollFirst: true);
      await tapByKey(
        $,
        const ValueKey('substitute_teacher_select_teacher_2'),
        scrollFirst: true,
      );
      final listView = find.byType(ListView);
      for (var i = 0; i < 10; i++) {
        await $.tester.drag(listView.first, const Offset(0, -450));
        await $.pump(const Duration(milliseconds: 250));
      }
      await tapByKey($, QaTestKeys.substituteAssignButton, scrollFirst: false);
      await assertSnackBarText($, 'Substitute assigned',
          timeout: const Duration(seconds: 30));
    },
  );
}
