import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: education report remark publish E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.education);
      await assertVisibleText($, 'Education Suite');
      await $(QaTestKeys.educationReportRemarksTab).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 5));
      await $('Generate remark').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.educationPublishRemarkButton);
      await $.tester.ensureVisible(find.byKey(QaTestKeys.educationPublishRemarkButton));
      await $.tester.tap(find.byKey(QaTestKeys.educationPublishRemarkButton));
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.educationRemarkPublishedSnackbar);
    },
  );
}
