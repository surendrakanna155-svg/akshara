import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/audit/audit_provider.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_security_providers.dart';
import '../../core/auth/auth_session_manager.dart';
import '../../core/auth/token_refresh_service.dart';
import '../../core/providers/shared_preferences_provider.dart';
import '../../core/security/server_permission_models.dart';
import '../../core/security/server_permission_provider.dart';
import '../../core/security/erp_role.dart';
import 'auth_claims.dart';
import 'auth_models.dart';
import 'auth_session_storage.dart';
import 'auth_token_models.dart';
import 'auth_token_provider.dart';
import 'staff/staff_login_provider.dart';

/// Demo OTP accepted by mock verification (any 6-digit code also works).
const String kMockValidOtp = '123456';

/// Mock display names per demo role.
const String kMockGuardianName = 'Suresh Kumar';
const String kMockTeacherName = 'Priya Sharma';
const String kMockStudentName = 'Ravi Kumar';

/// Mock linked children for parent accounts.
const List<LinkedChild> kMockLinkedChildren = [
  LinkedChild(id: 'child-ravi', name: 'Ravi Kumar', classLabel: '8-A'),
  LinkedChild(id: 'child-priya', name: 'Priya Kumar', classLabel: '5-B'),
];

final authSessionStorageProvider = Provider<AuthSessionStorage>((ref) {
  return AuthSessionStorage(ref.watch(sharedPreferencesProvider));
});

/// Demo role pre-selected on the login screen (persisted locally).
final demoLoginRoleProvider = StateProvider<UserRole>((ref) {
  final storage = ref.watch(authSessionStorageProvider);
  return storage.readDemoRolePreferenceSync() ?? UserRole.parent;
});

/// Staff ERP role for demo staff sessions (persisted locally).
final staffErpRoleProvider = StateProvider<ErpRole>((ref) {
  final storage = ref.watch(authSessionStorageProvider);
  return storage.readStaffErpRolePreferenceSync() ?? ErpRole.superAdmin;
});

/// Currently selected child — convenience for parent feature modules.
final selectedChildProvider = Provider<LinkedChild?>((ref) {
  return ref.watch(authProvider).selectedChild;
});

/// Auth controller with SharedPreferences session persistence.
class AuthNotifier extends Notifier<AuthState> {
  late final AuthSessionStorage _storage;

  @override
  AuthState build() {
    _storage = ref.read(authSessionStorageProvider);
    return const AuthState(status: AuthStatus.unknown);
  }

  /// Persists the demo role selector choice for the next login.
  Future<void> setDemoLoginRole(UserRole role) async {
    await _storage.writeDemoRolePreference(role);
    ref.read(demoLoginRoleProvider.notifier).state = role;
  }

  /// Restores persisted session from device storage (splash / cold start).
  Future<void> resolveSession() async {
    if (state.isSessionResolved) {
      return;
    }

    await loadCachedServerPermissions(ref);

    final persisted = await _storage.read();
    if (persisted == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    final role = UserRole.fromName(persisted.role) ?? UserRole.parent;
    final selectedChild = persisted.hasSelectedChild
        ? LinkedChild(
            id: persisted.selectedChildId,
            name: persisted.selectedChildName,
            classLabel: persisted.selectedChildClass,
          )
        : null;

    final tokenStorage = ref.read(tokenStorageProvider);
    final tokens = await tokenStorage.read();
    var claims = persisted.claims ?? _claimsForRole(role);
    final sessionMetadata = await ref.read(sessionMetadataStorageProvider).read();

    final sessionManager = ref.read(authSessionManagerProvider);
    final restore = await sessionManager.restoreSession(
      tokens: tokens,
      claims: claims,
      sessionMetadata: sessionMetadata,
      refreshCallback: ref.read(tokenRefreshCallbackProvider),
      onTokensRefreshed: tokenStorage.write,
      onEvent: (event) {
        if (event == AuthSessionEvent.expired) {
          logout();
        }
      },
    );

    if (!restore.isValid) {
      await logout();
      return;
    }

    claims = restore.claims ?? claims;
    final activeTokens = restore.tokens ?? tokens;
    if (activeTokens != null) {
      _scheduleRefresh(activeTokens);
      await _touchSessionMetadata(activeTokens);
    }

    if (claims != null && isAuthApiEnabled(ref)) {
      await syncAuthPermissions(
        ref,
        userId: claims.userId,
        tenantId: claims.tenantId,
      );
    }

    state = AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: persisted.phoneNumber,
      displayName: persisted.displayName,
      role: role,
      selectedChild: selectedChild,
      linkedChildren: _linkedChildrenForRole(role),
      claims: claims,
    );
  }

  /// Persists staff ERP role for the next staff session.
  Future<void> setStaffErpRole(ErpRole erpRole) async {
    await _storage.writeStaffErpRolePreference(erpRole);
    ref.read(staffErpRoleProvider.notifier).state = erpRole;
    if (state.isAuthenticated && state.role == UserRole.staff) {
      final previous = state.claims?.erpRole;
      state = state.copyWith(
        claims: AuthClaims.demoForRole(erpRole: erpRole, userId: state.claims?.userId),
      );
      await _persistSession();
      if (previous != erpRole) {
        await recordAuditEvent(
          ref,
          type: AuditEventType.roleChange,
          userId: state.claims?.userId,
          tenantId: state.claims?.tenantId,
          metadata: {
            'from': previous?.name ?? '',
            'to': erpRole.name,
          },
        );
      }
    }
  }

  /// Sends a mock OTP to [phoneNumber] for the selected demo [role].
  Future<bool> sendOtp(String phoneNumber, UserRole role) async {
    final normalized = _normalizePhone(phoneNumber);
    if (normalized.length != 10) {
      return false;
    }

    if (!kDemoLoginRoles.contains(role)) {
      return false;
    }

    await _storage.writeDemoRolePreference(role);
    ref.read(demoLoginRoleProvider.notifier).state = role;

    await Future<void>.delayed(const Duration(milliseconds: 600));
    state = AuthState(
      status: AuthStatus.otpPending,
      phoneNumber: normalized,
      role: role,
    );
    return true;
  }

  /// Verifies OTP. Accepts [kMockValidOtp] or any 6-digit code in mock mode.
  Future<bool> verifyOtp(String otp) async {
    if (state.status != AuthStatus.otpPending) {
      return false;
    }

    final code = otp.trim();
    final isValid = code == kMockValidOtp ||
        (code.length == 6 && int.tryParse(code) != null);
    if (!isValid) {
      return false;
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));

    final role = state.role ?? _storage.readDemoRolePreferenceSync() ?? UserRole.parent;
    final session = _authenticatedSessionForRole(role);

    state = AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: state.phoneNumber,
      displayName: session.displayName,
      role: role,
      selectedChild: session.selectedChild,
      linkedChildren: session.linkedChildren,
      claims: _claimsForRole(role),
    );

    await _persistSession();
    await _issueDemoTokens();
    await _auditLogin();
    return true;
  }

  /// Completes production staff login after OTP verification.
  Future<void> completeStaffLogin(StaffAuthResult result) async {
    await _storage.writeStaffErpRolePreference(result.claims.erpRole);
    await _storage.writeRememberStaffSession(result.rememberSession);
    ref.read(staffErpRoleProvider.notifier).state = result.claims.erpRole;

    final identifier = ref.read(staffLoginProvider).identifier;

    state = AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: identifier,
      displayName: result.displayName,
      role: UserRole.staff,
      claims: result.claims,
    );

    await ref.read(tokenStorageProvider).write(result.tokens);
    if (result.rememberSession) {
      await _persistSession();
    }
    _scheduleRefresh(result.tokens);

    if (isAuthApiEnabled(ref)) {
      await syncAuthPermissions(
        ref,
        userId: result.claims.userId,
        tenantId: result.claims.tenantId,
      );
    }

    if (!isAuthApiEnabled(ref)) {
      await _auditLogin();
    }
  }

  /// Establishes a staff ERP session with mock JWT claims (tests / dev tools).
  Future<void> signInStaff({
    required String phoneNumber,
    required String displayName,
    ErpRole? erpRole,
  }) async {
    final ErpRole resolvedErpRole =
        erpRole ?? ref.read(staffErpRoleProvider);
    await _storage.writeStaffErpRolePreference(resolvedErpRole);
    ref.read(staffErpRoleProvider.notifier).state = resolvedErpRole;

    state = AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: _normalizePhone(phoneNumber),
      displayName: displayName,
      role: UserRole.staff,
      claims: AuthClaims.demoForRole(
        erpRole: resolvedErpRole,
        userId: 'user_${_normalizePhone(phoneNumber)}',
      ),
    );
    await _persistSession();
    await _issueDemoTokens();
    await _auditLogin();
  }

  /// Updates active child and persists selection for next app launch.
  Future<void> selectChild(LinkedChild child) async {
    if (!state.isAuthenticated || state.role != UserRole.parent) {
      return;
    }

    final isLinked = state.linkedChildren.any((c) => c.id == child.id);
    if (!isLinked) {
      return;
    }

    state = state.copyWith(selectedChild: child);
    await _storage.writeSelectedChild(child);
  }

  /// Updates active child by id.
  Future<void> selectChildById(String childId) async {
    for (final child in state.linkedChildren) {
      if (child.id == childId) {
        await selectChild(child);
        return;
      }
    }
  }

  Future<void> logout() async {
    final userId = state.claims?.userId;
    final tenantId = state.claims?.tenantId;
    ref.read(authSessionManagerProvider).resetSecurityState();

    if (isAuthApiEnabled(ref)) {
      await ref.read(authRepositoryProvider).logout();
    }

    await _storage.clear();
    await ref.read(tokenStorageProvider).clear();
    await ref.read(sessionMetadataStorageProvider).clear();
    await ref.read(tokenRevocationServiceProvider).clearLocalRevocations();
    await ref.read(serverPermissionCacheProvider).clear();
    ref.read(serverPermissionSyncProvider.notifier).state =
        const ServerPermissionSyncState();
    state = const AuthState(status: AuthStatus.unauthenticated);

    if (!isAuthApiEnabled(ref)) {
      await recordAuditEvent(
        ref,
        type: AuditEventType.logout,
        userId: userId,
        tenantId: tenantId,
      );
    }
  }

  /// Revokes all server sessions and clears the local auth state.
  Future<void> logoutAll() async {
    await ref.read(tokenRevocationServiceProvider).revokeAllSessions();
    await logout();
  }

  /// Issues mock API tokens and syncs expiry into [AuthClaims].
  Future<void> _issueDemoTokens() async {
    final tokens = AuthTokens.demo();
    await ref.read(tokenStorageProvider).write(tokens);
    final claims = state.claims;
    if (claims != null) {
      state = state.copyWith(
        claims: claims.copyWith(accessTokenExpiresAt: tokens.expiresAt),
      );
      await _persistSession();
    }
    _scheduleRefresh(tokens);
  }

  void _scheduleRefresh(AuthTokens tokens) {
    ref.read(authSessionManagerProvider).scheduleTokenRefresh(
          tokens: tokens,
          onRefreshDue: () async {
            final refreshCallback = ref.read(tokenRefreshCallbackProvider);
            final current = await ref.read(tokenStorageProvider).read();
            if (current == null || refreshCallback == null) return;

            final outcome = await ref
                .read(tokenRefreshServiceProvider)
                .refreshIfNeeded(
                  tokens: current,
                  refreshCallback: refreshCallback,
                  onRefreshed: (refreshed) async {
                    ref
                        .read(authSessionManagerProvider)
                        .recordTokenRotation(previous: current, next: refreshed);
                    await ref.read(tokenStorageProvider).write(refreshed);
                    final claims = state.claims;
                    if (claims != null) {
                      state = state.copyWith(
                        claims: claims.copyWith(
                          accessTokenExpiresAt: refreshed.expiresAt,
                        ),
                      );
                      await _persistSession();
                      if (isAuthApiEnabled(ref)) {
                        await syncAuthPermissions(
                          ref,
                          userId: claims.userId,
                          tenantId: claims.tenantId,
                        );
                      }
                    }
                    _scheduleRefresh(refreshed);
                  },
                );

            if (outcome.status == TokenRefreshStatus.expired) {
              await logout();
            }
          },
        );
  }

  Future<void> _touchSessionMetadata(AuthTokens tokens) async {
    final storage = ref.read(sessionMetadataStorageProvider);
    final policy = ref.read(sessionExpirationPolicyProvider);
    final existing = await storage.read();
    final metadata = ref.read(authSessionManagerProvider).touchSession(
          existing ??
              policy.startSession(
                sessionId: tokens.sessionId,
                deviceId: tokens.deviceId,
              ),
        );
    await storage.write(metadata);
  }

  Future<void> _auditLogin() async {
    await recordAuditEvent(
      ref,
      type: AuditEventType.login,
      userId: state.claims?.userId,
      tenantId: state.claims?.tenantId,
      schoolId: state.claims?.schoolId,
      metadata: {
        'role': state.role?.name ?? '',
        'erpRole': state.claims?.erpRole.name ?? '',
      },
    );
  }

  Future<void> _persistSession() async {
    if (!state.isAuthenticated) {
      return;
    }
    await _storage.write(state);
  }

  _RoleSession _authenticatedSessionForRole(UserRole role) {
    return switch (role) {
      UserRole.parent => _RoleSession(
          displayName: kMockGuardianName,
          selectedChild: kMockLinkedChildren.first,
          linkedChildren: kMockLinkedChildren,
        ),
      UserRole.teacher => const _RoleSession(
          displayName: kMockTeacherName,
        ),
      UserRole.student => const _RoleSession(
          displayName: kMockStudentName,
        ),
      UserRole.staff => const _RoleSession(
          displayName: kMockTeacherName,
        ),
    };
  }

  List<LinkedChild> _linkedChildrenForRole(UserRole? role) {
    return switch (role) {
      UserRole.parent => kMockLinkedChildren,
      _ => const [],
    };
  }

  AuthClaims? _claimsForRole(UserRole role) {
    return switch (role) {
      UserRole.staff => AuthClaims.demoForRole(
          erpRole: ref.read(staffErpRoleProvider),
          userId: state.phoneNumber != null
              ? 'user_${state.phoneNumber}'
              : 'user_staff_demo',
        ),
      UserRole.teacher => AuthClaims.demoForRole(erpRole: ErpRole.teacher),
      UserRole.parent => AuthClaims.demoForRole(erpRole: ErpRole.parent),
      UserRole.student => AuthClaims.demoForRole(erpRole: ErpRole.student),
    };
  }

  String _normalizePhone(String raw) {
    return raw.replaceAll(RegExp(r'\D'), '');
  }
}

class _RoleSession {
  const _RoleSession({
    required this.displayName,
    this.selectedChild,
    this.linkedChildren = const [],
  });

  final String displayName;
  final LinkedChild? selectedChild;
  final List<LinkedChild> linkedChildren;
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
