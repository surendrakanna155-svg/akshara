import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'red-team: parent transport quick action journey',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleKey($, QaTestKeys.parentDashboardScreen);

      await tapParentDashboardQuickAction($, 'transport');
      await assertPatrolRoute($, RouteNames.parentTransport);
      await assertVisibleKey($, QaTestKeys.parentTransportScreen);
      await assertVisibleText($, 'School Transport');
      await assertVisibleText($, 'Route');
      await assertVisibleText($, 'Bus');

      await tapParentHome($);
      await assertVisibleKey($, QaTestKeys.parentDashboardScreen);
      await assertVisibleText($, 'Pay Fee');
    },
  );

  patrolTest(
    'red-team: parent PTM quick action journey',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleKey($, QaTestKeys.parentDashboardScreen);

      await tapParentDashboardQuickAction($, 'ptm');
      await assertPatrolRoute($, RouteNames.parentPtm);
      await assertVisibleKey($, QaTestKeys.parentPtmScreen);
      await assertVisibleText($, 'Parent-Teacher Meetings');
      await assertVisibleText($, 'Mrs. Sharma');

      await tapParentHome($);
      await assertVisibleKey($, QaTestKeys.parentDashboardScreen);
    },
  );

  patrolTest(
    'red-team: parent notice n3 deep link opens transport',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin(
        $,
        QaLoginPersona.parent,
        extraOverrides: [parentPatrolNoticeFirstOverride('n3')],
      );
      await assertVisibleText($, 'School Notices');
      await scrollModuleBody($, 'School Notices', times: 4);
      await tapByKey($, QaTestKeys.parentDashboardNotice('n3'));
      await assertPatrolRoute($, RouteNames.parentTransport);
      await assertVisibleKey($, QaTestKeys.parentTransportScreen);
      await assertVisibleText($, 'School Transport');
    },
  );

  patrolTest(
    'red-team: parent notice n1 deep link opens PTM',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin(
        $,
        QaLoginPersona.parent,
        extraOverrides: [parentPatrolNoticeFirstOverride('n1')],
      );
      await assertVisibleText($, 'School Notices');
      await scrollModuleBody($, 'School Notices', times: 4);
      await tapByKey($, QaTestKeys.parentDashboardNotice('n1'));
      await assertPatrolRoute($, RouteNames.parentPtm);
      await assertVisibleKey($, QaTestKeys.parentPtmScreen);
      await assertVisibleText($, 'Parent-Teacher Meetings');
    },
  );
}
