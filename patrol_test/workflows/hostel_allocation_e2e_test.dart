import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/hostel_allocation_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: hostel room allocation E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.hostelStudents);
      await assertVisibleText($, 'Hostel residents');
      await assignHostelRoomForStudent($, 'ho_stu_5');
      await goToErpRoute($, RouteNames.hostelStudents);
      await checkoutHostelStudentRow($, 'ho_stu_2');
    },
  );
}
