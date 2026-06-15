import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/white_label/branding_profiles_screen.dart';
import '../features/white_label/deployment_profiles_screen.dart';
import '../features/white_label/logo_management_screen.dart';
import '../features/white_label/theme_management_screen.dart';
import '../features/white_label/white_label_hub_screen.dart';

Widget whiteLabelHubRouteBuilder(BuildContext context, GoRouterState state) =>
    const WhiteLabelHubScreen();

Widget whiteLabelBrandingRouteBuilder(BuildContext context, GoRouterState state) =>
    const BrandingProfilesScreen();

Widget whiteLabelThemeRouteBuilder(BuildContext context, GoRouterState state) =>
    const ThemeManagementScreen();

Widget whiteLabelLogoRouteBuilder(BuildContext context, GoRouterState state) =>
    const LogoManagementScreen();

Widget whiteLabelDeploymentRouteBuilder(
  BuildContext context,
  GoRouterState state,
) =>
    const DeploymentProfilesScreen();
