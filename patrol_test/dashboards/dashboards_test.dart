import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  final dashboardCases = <(QaLoginPersona, String, List<String>)>[
    (QaLoginPersona.principal, 'principal', ['Principal overview', 'Quick']),
    (QaLoginPersona.teacher, 'teacher', ["Today's Classes", 'Quick Actions']),
    (QaLoginPersona.parent, 'parent', ['Fees', 'School Notices']),
    (QaLoginPersona.student, 'student', ['Home']),
    (QaLoginPersona.finance, 'finance', ['Fee Collected (MTD)']),
    (QaLoginPersona.inventory, 'inventory', ['Total Assets']),
    (QaLoginPersona.superAdmin, 'super_admin', ['Admin Hub']),
  ];

  for (final (persona, slug, anchors) in dashboardCases) {
    patrolTest(
      'dashboard: ${persona.buttonLabel} dashboard renders KPIs and cards',
      config: aksharaPatrolConfig(),
      ($) async {
        await bootstrapAndLogin($, persona);
        for (final anchor in anchors) {
          await assertVisibleText($, anchor);
        }
        await capturePatrolScreenshot($, 'dashboard_$slug', subdir: 'dashboards');
      },
    );
  }

  patrolTest(
    'dashboard: intelligence hub opens from principal overview',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await $('Analytics').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await assertVisibleText($, 'Analytics');
      await capturePatrolScreenshot($, 'dashboard_intelligence', subdir: 'dashboards');
    },
  );

  patrolTest(
    'dashboard: parent quick navigation — fees tab',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await $('Fees').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await capturePatrolScreenshot($, 'dashboard_parent_fees_tab', subdir: 'dashboards');
    },
  );

  patrolTest(
    'dashboard: teacher quick actions section visible',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, 'Quick Actions');
    },
  );
}
