import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: healthcare patients and appointments navigation',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);

      await goToErpRoute($, RouteNames.healthcarePatients);
      await waitForLoadingToClear($, timeout: const Duration(seconds: 30));
      await assertVisibleKey($, QaTestKeys.healthcarePatientScreen);

      await goToErpRoute($, RouteNames.healthcareAppointments);
      await waitForLoadingToClear($, timeout: const Duration(seconds: 30));
      await assertVisibleKey($, QaTestKeys.healthcareAppointmentScreen);
    },
  );
}
