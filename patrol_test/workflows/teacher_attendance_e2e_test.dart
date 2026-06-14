import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';
import '../helpers/teacher_journey_helpers.dart';

/// Teacher attendance submit with navigation persistence check.
void main() {
  patrolTest(
    'journey: teacher attendance submit persists after navigation',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await tapBottomNav($, 'Classes');
      await submitClassAttendance($);
      await assertSubmitDisabled($);
      await verifyAttendanceSubmissionPersists($);
    },
  );
}
