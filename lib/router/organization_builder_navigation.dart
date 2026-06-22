import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/platform/organization_builder/organization_builder_hub_screen.dart';
import '../features/platform/organization_builder/organization_builder_interview_screen.dart';
import '../features/platform/organization_builder/organization_builder_preview_screen.dart';
import '../features/platform/organization_builder/organization_provisioning_screen.dart';

Widget organizationBuilderHubRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const OrganizationBuilderHubScreen();
}

Widget organizationBuilderInterviewRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  final draftId = state.uri.queryParameters['draftId'] ?? '';
  final packId = state.uri.queryParameters['packId'] ?? 'pack_school';
  return OrganizationBuilderInterviewScreen(
    draftId: draftId,
    packId: packId,
  );
}

Widget organizationBuilderPreviewRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  final draftId = state.uri.queryParameters['draftId'] ?? '';
  return OrganizationBuilderPreviewScreen(draftId: draftId);
}

Widget organizationBuilderProvisioningRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  final jobId = state.uri.queryParameters['jobId'] ?? '';
  return OrganizationProvisioningScreen(jobId: jobId);
}
