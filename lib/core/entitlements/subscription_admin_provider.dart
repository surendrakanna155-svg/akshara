import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/erp_role.dart';
import '../security/permissions.dart';
import '../security/rbac_service.dart';
import 'entitlement_models.dart';
import 'entitlement_provider.dart';

/// B2 — Step 4.5 · providers for the superAdmin plan-assignment screen.
///
/// Visibility is gated to superAdmin (the only role granted
/// `managePlatformSubscriptions` server-side); the backend remains the real
/// enforcement. Read-only listing + a single assign action — no billing.

/// Whether the current user may assign organization plans.
///
/// JOURNEY-002 — this was **role-only**. Combined with the `?? ErpRole.superAdmin`
/// login fallback it meant an office clerk or a school nurse (any server role the
/// client enum did not know) rendered the organization plan-assignment screen
/// *and its Save action*. The fallback is fixed at the source, but a role-only
/// gate is one enum drift away from the same outcome, so the check is now a
/// conjunct: hold the role **and** hold a platform-administration permission the
/// server actually seeded for that session.
///
/// `manageControlCenter` is the client-side stand-in for the server's
/// `managePlatformSubscriptions` grant (there is no client [Permission] for it);
/// both are seeded to the same platform-admin role set, and the backend remains
/// the real enforcement on `POST /platform/subscriptions`.
final canAssignOrganizationPlansProvider = Provider<bool>((ref) {
  final perms = ref.watch(userPermissionsProvider);
  if (perms == null) return false;
  return perms.hasRole(ErpRole.superAdmin) &&
      perms.has(Permission.manageControlCenter);
});

/// Lists every organization with its current plan (drives the assign screen).
/// Empty when the entitlement layer is disabled or the call fails.
final assignableOrganizationsProvider =
    FutureProvider<List<OrganizationPlanAssignment>>((ref) async {
  final api = ref.watch(entitlementApiRepositoryProvider);
  if (api == null) return const [];
  return api.fetchAssignableOrganizations();
});

/// Imperative assignment action used by the screen's Save button.
final assignSubscriptionActionProvider =
    Provider<Future<OrganizationPlanAssignment> Function({
  required String organizationId,
  required String planSlug,
  String? status,
})>((ref) {
  return ({
    required String organizationId,
    required String planSlug,
    String? status,
  }) async {
    final api = ref.read(entitlementApiRepositoryProvider);
    if (api == null) {
      throw StateError('Entitlement API is not enabled');
    }
    final result = await api.assignSubscription(
      organizationId: organizationId,
      planSlug: planSlug,
      status: status,
    );
    // Refresh the org list + the current-org subscription view.
    ref.invalidate(assignableOrganizationsProvider);
    await ref.read(subscriptionProvider.notifier).refresh();
    return result;
  };
});
