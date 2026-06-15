import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: reassign teacher periods',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.teacherReassignment);

      await $('Teacher Reassignment Wizard').waitUntilVisible();
      await tapByKey(
        $,
        const ValueKey('teacher_reassignment_slot_trs_1'),
        scrollFirst: false,
      );
      await tapByKey(
        $,
        const ValueKey('teacher_reassignment_select_teacher_2'),
        scrollFirst: false,
      );
      await tapByKey($, QaTestKeys.teacherReassignmentSubmitButton, scrollFirst: false);

      await assertVisibleKey($, QaTestKeys.teacherReassignmentSuccessSnackbar);
    },
  );
}
