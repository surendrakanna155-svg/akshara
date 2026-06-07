import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/security/erp_role.dart';
import 'auth_claims.dart';
import 'auth_models.dart';

/// SharedPreferences key — bump suffix when persisted schema changes.
const String kAuthSessionStorageKey = 'auth_session_v2';

/// Legacy session key (migrated on read).
const String kAuthSessionStorageKeyV1 = 'auth_session_v1';

/// Last demo role chosen on the login screen.
const String kDemoRolePreferenceKey = 'demo_role_preference';

/// Staff ERP role for demo staff sessions.
const String kStaffErpRolePreferenceKey = 'staff_erp_role_preference';

/// Whether staff chose "remember session" on staff login.
const String kRememberStaffSessionKey = 'remember_staff_session_v1';

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
    this.claims,
  });

  final bool isLoggedIn;
  final String phoneNumber;
  final String displayName;
  final String role;
  final String selectedChildId;
  final String selectedChildName;
  final String selectedChildClass;
  final AuthClaims? claims;

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
      claims: state.claims,
    );
  }

  factory PersistedAuthSession.fromJson(Map<String, dynamic> json) {
    final claimsJson = json['claims'];
    return PersistedAuthSession(
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      selectedChildId: json['selectedChildId'] as String? ?? '',
      selectedChildName: json['selectedChildName'] as String? ?? '',
      selectedChildClass: json['selectedChildClass'] as String? ?? '',
      claims: claimsJson is Map<String, dynamic>
          ? AuthClaims.fromJson(claimsJson)
          : null,
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
        if (claims != null) 'claims': claims!.toJson(),
      };

  bool get isValid {
    final roleEnum = UserRole.fromName(role);
    if (!isLoggedIn || displayName.isEmpty || roleEnum == null) {
      return false;
    }

    if (roleEnum == UserRole.staff) {
      return phoneNumber.isNotEmpty;
    }

    if (phoneNumber.length != 10) {
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

  ErpRole? readStaffErpRolePreferenceSync() {
    return ErpRole.fromName(_prefs.getString(kStaffErpRolePreferenceKey));
  }

  Future<void> writeDemoRolePreference(UserRole role) async {
    await _prefs.setString(kDemoRolePreferenceKey, role.name);
  }

  Future<void> writeStaffErpRolePreference(ErpRole role) async {
    await _prefs.setString(kStaffErpRolePreferenceKey, role.name);
  }

  bool readRememberStaffSessionSync() {
    return _prefs.getBool(kRememberStaffSessionKey) ?? true;
  }

  Future<void> writeRememberStaffSession(bool value) async {
    await _prefs.setBool(kRememberStaffSessionKey, value);
  }

  Future<PersistedAuthSession?> read() async {
    var raw = _prefs.getString(kAuthSessionStorageKey);
    if (raw == null || raw.isEmpty) {
      raw = _prefs.getString(kAuthSessionStorageKeyV1);
      if (raw == null || raw.isEmpty) {
        return null;
      }
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
