import 'dart:convert';

import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_session_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late AuthSessionStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = AuthSessionStorage(prefs);
  });

  AuthState parentSession() {
    return const AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: '9876543210',
      displayName: 'Suresh Kumar',
      role: UserRole.parent,
      selectedChild: LinkedChild(
        id: 'child-ravi',
        name: 'Ravi Kumar',
        classLabel: '8-A',
      ),
      linkedChildren: [
        LinkedChild(id: 'child-ravi', name: 'Ravi Kumar', classLabel: '8-A'),
      ],
    );
  }

  test('write and read round-trips a parent session', () async {
    await storage.write(parentSession());

    final restored = await storage.read();

    expect(restored, isNotNull);
    expect(restored!.phoneNumber, '9876543210');
    expect(restored.displayName, 'Suresh Kumar');
    expect(restored.role, UserRole.parent.name);
    expect(restored.selectedChildId, 'child-ravi');
    expect(restored.selectedChildName, 'Ravi Kumar');
    expect(restored.selectedChildClass, '8-A');
  });

  test('invalid JSON clears persisted session', () async {
    await prefs.setString(kAuthSessionStorageKey, '{not-json');

    final restored = await storage.read();

    expect(restored, isNull);
    expect(prefs.getString(kAuthSessionStorageKey), isNull);
  });

  test('parent session without child is rejected', () async {
    await prefs.setString(
      kAuthSessionStorageKey,
      jsonEncode({
        'isLoggedIn': true,
        'phoneNumber': '9876543210',
        'displayName': 'Suresh Kumar',
        'role': 'parent',
        'selectedChildId': '',
        'selectedChildName': '',
        'selectedChildClass': '',
      }),
    );

    final restored = await storage.read();

    expect(restored, isNull);
    expect(prefs.getString(kAuthSessionStorageKey), isNull);
  });

  test('writeSelectedChild updates persisted snapshot', () async {
    await storage.write(parentSession());

    await storage.writeSelectedChild(
      const LinkedChild(
        id: 'child-priya',
        name: 'Priya Kumar',
        classLabel: '5-B',
      ),
    );

    final restored = await storage.read();

    expect(restored?.selectedChildId, 'child-priya');
    expect(restored?.selectedChildName, 'Priya Kumar');
    expect(restored?.selectedChildClass, '5-B');
  });

  test('demo role preference persists synchronously', () async {
    await storage.writeDemoRolePreference(UserRole.teacher);

    expect(storage.readDemoRolePreferenceSync(), UserRole.teacher);
  });

  test('clear removes auth session key', () async {
    await storage.write(parentSession());
    await storage.clear();

    expect(await storage.read(), isNull);
  });
}
