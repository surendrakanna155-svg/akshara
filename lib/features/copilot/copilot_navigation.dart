import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_names.dart';
import 'copilot_context_provider.dart';
import 'copilot_provider.dart';
import 'copilot_role_intelligence.dart';
import 'dock/copilot_dock_provider.dart';

/// Opens copilot with the originating screen context attached (INTEL-03).
void openCopilotWithCurrentContext(BuildContext context, WidgetRef ref) {
  final originRoute = GoRouterState.of(context).uri.path;
  final override = ref.read(copilotScreenOverrideProvider);
  final contextPayload = override?.copyWith(originRoute: originRoute) ??
      buildCopilotScreenContext(ref, originRoute: originRoute);

  ref.read(copilotPendingNavigationContextProvider.notifier).state = contextPayload;

  final suggested = contextPayload.suggestedAssistant ??
      defaultAssistantForPersona(contextPayload.personaRole);
  ref.read(copilotSelectedAssistantProvider.notifier).state = suggested;

  ref.read(copilotDockExpandedProvider.notifier).state = false;
  context.go(RouteNames.copilot);
}

/// Opens full copilot (staff) or persona shell (mobile personas) from dock (INTEL-04).
void openAiAssistantFromDock(BuildContext context, WidgetRef ref) {
  final originRoute = GoRouterState.of(context).uri.path;
  final override = ref.read(copilotScreenOverrideProvider);
  final contextPayload = override?.copyWith(originRoute: originRoute) ??
      buildCopilotScreenContext(ref, originRoute: originRoute);

  ref.read(copilotPendingNavigationContextProvider.notifier).state = contextPayload;
  ref.read(copilotDockExpandedProvider.notifier).state = false;

  if (ref.read(copilotCanUseProvider)) {
    final suggested = contextPayload.suggestedAssistant ??
        defaultAssistantForPersona(contextPayload.personaRole);
    ref.read(copilotSelectedAssistantProvider.notifier).state = suggested;
    context.go(RouteNames.copilot);
    return;
  }

  context.push(RouteNames.aiAssistant);
}

/// Capture context and open persona shell (mobile entry points).
void openAiPersonaAssistant(BuildContext context, WidgetRef ref) {
  final originRoute = GoRouterState.of(context).uri.path;
  ref.read(copilotPendingNavigationContextProvider.notifier).state =
      buildCopilotScreenContext(ref, originRoute: originRoute);
  context.push(RouteNames.aiAssistant);
}
