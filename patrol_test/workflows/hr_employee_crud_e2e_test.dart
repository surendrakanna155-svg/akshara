import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/hr_employee_crud_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// HR employee CRUD journey (mock mode).
void main() {
  patrolTest(
    'journey: hr employee create edit activate deactivate E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.hrEmployees);
      await assertVisibleText($, 'Employee directory');
      await createHrEmployeeFromDirectory($);

      const createdEmployeeId = 'HR-EMP-201';
      await goToErpRoute($, RouteNames.hrEmployeeDetail(createdEmployeeId));
      await assertVisibleText($, 'QA Staff Member');
      await editHrEmployeeProfile($, createdEmployeeId);
      await deactivateHrEmployeeProfile($, createdEmployeeId);
      await activateHrEmployeeProfile($, createdEmployeeId);
    },
  );
}
