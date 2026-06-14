import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/auth_provider.dart';
import '../../../router/route_names.dart';
import '../copilot_provider.dart';
import '../copilot_role_intelligence.dart';

/// Whether the floating dock panel is expanded (INTEL-04).
final copilotDockExpandedProvider = StateProvider<bool>((ref) => false);

/// Routes where the floating dock is hidden (already in AI surfaces).
const _hiddenDockRoutes = {
  RouteNames.copilot,
  RouteNames.aiAssistant,
};

bool copilotDockHiddenForRoute(String route) {
  for (final hidden in _hiddenDockRoutes) {
    if (route == hidden || route.startsWith('$hidden/')) return true;
  }
  return false;
}

/// True when the floating dock should render on the current route.
final copilotDockVisibleProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return false;
  return true;
});

/// ERP staff may open full copilot; mobile personas use persona shell.
final copilotDockUsesFullCopilotProvider = Provider<bool>((ref) {
  return ref.watch(copilotCanUseProvider);
});

IconData copilotDockIconForPersona(CopilotPersonaRole persona) => switch (persona) {
      CopilotPersonaRole.platformOwner ||
      CopilotPersonaRole.organizationOwner =>
        Icons.hub_outlined,
      CopilotPersonaRole.directorCorrespondent => Icons.insights_outlined,
      CopilotPersonaRole.principal => Icons.school_outlined,
      CopilotPersonaRole.academicCoordinator => Icons.menu_book_outlined,
      CopilotPersonaRole.teacher => Icons.co_present_outlined,
      CopilotPersonaRole.parent => Icons.family_restroom_outlined,
      CopilotPersonaRole.student => Icons.auto_stories_outlined,
    };

CopilotPersonaRole copilotDockPersona(WidgetRef ref) {
  final claims = ref.watch(authProvider).claims;
  if (claims == null) return CopilotPersonaRole.directorCorrespondent;
  return copilotPersonaForErpRole(claims.erpRole);
}

String copilotDockSemanticLabel(CopilotPersonaRole persona, {required bool expanded}) {
  final state = expanded ? 'expanded' : 'collapsed';
  return 'AI assistant dock, ${persona.label}, $state';
}
