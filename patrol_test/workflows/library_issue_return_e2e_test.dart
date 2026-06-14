import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/library_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: library issue and return E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.libraryIssues);
      await assertVisibleText($, 'Issue books');
      await issueLibraryBook($);

      await goToErpRoute($, RouteNames.libraryIssues);
      await returnLibraryBook($, 'iss_2');
    },
  );
}
