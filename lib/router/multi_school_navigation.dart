import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/multi_school/multi_school_portfolio_screen.dart';
import '../features/multi_school/school_onboarding_wizard_screen.dart';

Widget multiSchoolPortfolioRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const MultiSchoolPortfolioScreen();
}

Widget multiSchoolOnboardingRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const SchoolOnboardingWizardScreen();
}
