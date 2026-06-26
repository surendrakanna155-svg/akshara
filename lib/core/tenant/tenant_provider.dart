import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_provider.dart';
import '../config/environment_provider.dart';
import '../repositories/repository_query.dart';
import 'tenant_context.dart';

/// Active tenant context derived from auth claims.
final tenantContextProvider = Provider<TenantContext>((ref) {
  final auth = ref.watch(authProvider);
  final claims = auth.claims;

  if (claims != null) {
    return TenantContext(
      tenantId: claims.tenantId,
      schoolId: claims.schoolId,
      organizationId: claims.organizationId,
      userId: claims.userId,
    );
  }

  if (auth.isAuthenticated) {
    // CORE-3: in LIVE/API mode an authenticated session must always carry claims
    // (hardened login logs out on null claims). Reaching here with API mode on
    // is a broken session — fail fast rather than silently shipping the demo
    // tenant identity (tenant_demo_001) to a real backend. In mock/demo mode an
    // authenticated session without claims is the intended demo behaviour.
    assert(
      !ref.watch(enableApiModeProvider),
      'Authenticated live session has null claims — refusing to assume the demo tenant.',
    );
    return TenantContext.demo.copyWith(
      userId: 'user_${auth.phoneNumber ?? 'anonymous'}',
    );
  }

  return TenantContext.demo;
});

/// Repository query for the active tenant session.
final repositoryQueryProvider = Provider<RepositoryQuery>((ref) {
  return ref.watch(tenantContextProvider).toQuery();
});

/// Full user + tenant snapshot for downstream services.
final currentUserContextProvider = Provider<CurrentUserContext?>((ref) {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.displayName == null) {
    return null;
  }

  return CurrentUserContext(
    tenant: ref.watch(tenantContextProvider),
    displayName: auth.displayName!,
    phoneNumber: auth.phoneNumber,
  );
});
