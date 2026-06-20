import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/rbac_service.dart';
import 'workspace.dart';

/// The workspaces available to the current session, derived from the user's
/// held roles (union, deduped, primary first). Empty when unauthenticated.
final userWorkspacesProvider = Provider<List<Workspace>>((ref) {
  final roles = ref.watch(rbacServiceProvider).roles;
  return workspacesForRoles(roles);
});

/// Whether the user has more than one workspace (drives the switcher UI).
final hasMultipleWorkspacesProvider = Provider<bool>((ref) {
  return ref.watch(userWorkspacesProvider).length > 1;
});

/// The currently-active workspace id. Null until resolved (defaults to the
/// user's first/primary workspace via [activeWorkspaceProvider]).
final activeWorkspaceIdProvider = StateProvider<WorkspaceId?>((ref) => null);

/// The resolved active workspace — the explicitly-selected one when valid for
/// this user, otherwise the user's primary (first) workspace.
final activeWorkspaceProvider = Provider<Workspace?>((ref) {
  final available = ref.watch(userWorkspacesProvider);
  if (available.isEmpty) return null;
  final selectedId = ref.watch(activeWorkspaceIdProvider);
  if (selectedId != null) {
    for (final ws in available) {
      if (ws.id == selectedId) return ws;
    }
  }
  return available.first;
});
