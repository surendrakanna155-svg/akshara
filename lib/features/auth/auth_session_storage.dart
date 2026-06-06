import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_models.dart';

/// SharedPreferences key — bump suffix when persisted schema changes.
const String kAuthSessionStorageKey = 'auth_session_v1';

/// Last demo role chosen on the login screen.
const String kDemoRolePreferenceKey = 'demo_role_preference';

/// Serializable session snapshot written to device storage.
class PersistedAuthSession {
  const PersistedAuthSession({
    required this.isLoggedIn,
    required this.phoneNumber,
    required this.displayName,
    required this.role,
    required this.selectedChildId,
    required this.selectedChildName,
    required this.selectedChildClass,
  });

  final bool isLoggedIn;
  final String phoneNumber;
  final String displayName;
  final String role;
  final String selectedChildId;
  final String selectedChildName;
  final String selectedChildClass;

  factory PersistedAuthSession.fromAuthState(AuthState state) {
    if (!state.isAuthenticated ||
        state.phoneNumber == null ||
        state.displayName == null ||
        state.role == null) {
      throw StateError('Cannot persist incomplete auth session');
    }

    final child = state.selectedChild;
    if (state.role == UserRole.parent && child == null) {
      throw StateError('Parent session requires a selected child');
    }

    return PersistedAuthSession(
      isLoggedIn: true,
      phoneNumber: state.phoneNumber!,
      displayName: state.displayName!,
      role: state.role!.name,
      selectedChildId: child?.id ?? '',
      selectedChildName: child?.name ?? '',
      selectedChildClass: child?.classLabel ?? '',
    );
  }

  factory PersistedAuthSession.fromJson(Map<String, dynamic> json) {
    return PersistedAuthSession(
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      selectedChildId: json['selectedChildId'] as String? ?? '',
      selectedChildName: json['selectedChildName'] as String? ?? '',
      selectedChildClass: json['selectedChildClass'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'isLoggedIn': isLoggedIn,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'role': role,
        'selectedChildId': selectedChildId,
        'selectedChildName': selectedChildName,
        'selectedChildClass': selectedChildClass,
      };

  bool get isValid {
    final roleEnum = UserRole.fromName(role);
    if (!isLoggedIn ||
        phoneNumber.length != 10 ||
        displayName.isEmpty ||
        roleEnum == null) {
      return false;
    }

    if (roleEnum == UserRole.parent) {
      return selectedChildId.isNotEmpty &&
          selectedChildName.isNotEmpty &&
          selectedChildClass.isNotEmpty;
    }

    return true;
  }

  bool get hasSelectedChild =>
      selectedChildId.isNotEmpty &&
      selectedChildName.isNotEmpty &&
      selectedChildClass.isNotEmpty;
}

/// Reads and writes auth session data via [SharedPreferences].
class AuthSessionStorage {
  AuthSessionStorage(this._prefs);

  final SharedPreferences _prefs;

  UserRole? readDemoRolePreferenceSync() {
    return UserRole.fromName(_prefs.getString(kDemoRolePreferenceKey));
  }

  Future<void> writeDemoRolePreference(UserRole role) async {
    await _prefs.setString(kDemoRolePreferenceKey, role.name);
  }

  Future<PersistedAuthSession?> read() async {
    final raw = _prefs.getString(kAuthSessionStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await clear();
        return null;
      }

      final session = PersistedAuthSession.fromJson(decoded);
      if (!session.isValid) {
        await clear();
        return null;
      }
      return session;
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> write(AuthState state) async {
    final snapshot = PersistedAuthSession.fromAuthState(state);
    await _prefs.setString(
      kAuthSessionStorageKey,
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<void> writeSelectedChild(LinkedChild child) async {
    final existing = await read();
    if (existing == null) {
      return;
    }

    final updated = PersistedAuthSession(
      isLoggedIn: existing.isLoggedIn,
      phoneNumber: existing.phoneNumber,
      displayName: existing.displayName,
      role: existing.role,
      selectedChildId: child.id,
      selectedChildName: child.name,
      selectedChildClass: child.classLabel,
    );

    await _prefs.setString(
      kAuthSessionStorageKey,
      jsonEncode(updated.toJson()),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(kAuthSessionStorageKey);
  }
}
