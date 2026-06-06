import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/shared_preferences_provider.dart';
import 'auth_models.dart';
import 'auth_session_storage.dart';

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

    final persisted = await _storage.read();
    if (persisted == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    final role = UserRole.fromName(persisted.role);
    final selectedChild = persisted.hasSelectedChild
        ? LinkedChild(
            id: persisted.selectedChildId,
            name: persisted.selectedChildName,
            classLabel: persisted.selectedChildClass,
          )
        : null;

    state = AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: persisted.phoneNumber,
      displayName: persisted.displayName,
      role: role,
      selectedChild: selectedChild,
      linkedChildren: _linkedChildrenForRole(role),
    );
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
    );

    await _persistSession();
    return true;
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
    await _storage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
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
