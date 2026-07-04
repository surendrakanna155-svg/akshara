import 'package:akshara_erp/core/auth/secure_storage_backend.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/auth_session_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_test_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: authStorageTestOverrides(prefs),
    );
  });

  tearDown(() {
    container.dispose();
  });

  AuthNotifier notifier() => container.read(authProvider.notifier);

  AuthState auth() => container.read(authProvider);

  test('sendOtp rejects invalid phone numbers', () async {
    expect(auth().status, AuthStatus.unknown);

    final ok = await notifier().sendOtp('123', UserRole.parent);

    expect(ok, isFalse);
    expect(auth().status, AuthStatus.unknown);
  });

  test('sendOtp moves session to otpPending', () async {
    final ok = await notifier().sendOtp('9876543210', UserRole.parent);

    expect(ok, isTrue);
    expect(auth().status, AuthStatus.otpPending);
    expect(auth().phoneNumber, '9876543210');
    expect(auth().role, UserRole.parent);
  });

  test('cancelOtpPending clears pending session for login navigation', () async {
    await notifier().sendOtp('9876543210', UserRole.parent);
    expect(auth().status, AuthStatus.otpPending);

    notifier().cancelOtpPending();

    expect(auth().status, AuthStatus.unauthenticated);
    expect(auth().phoneNumber, isNull);
  });

  test('verifyOtp rejects invalid OTP in demo mode', () async {
    await notifier().sendOtp('9876543210', UserRole.parent);
    final ok = await notifier().verifyOtp('000000');
    expect(ok, isFalse);
    expect(auth().isAuthenticated, isFalse);
  });

  test('verifyOtp authenticates parent and persists session', () async {
    await notifier().sendOtp('9876543210', UserRole.parent);
    final ok = await notifier().verifyOtp(kMockValidOtp);

    expect(ok, isTrue);
    expect(auth().isAuthenticated, isTrue);
    expect(auth().displayName, kMockGuardianName);
    expect(auth().selectedChild?.id, kMockLinkedChildren.first.id);

    final storage = AuthSessionStorage(PreferencesStorageBackend(prefs), prefs);
    final persisted = await storage.read();
    expect(persisted?.phoneNumber, '9876543210');
    expect(persisted?.role, UserRole.parent.name);
  });

  test('resolveSession restores persisted teacher session', () async {
    await AuthSessionStorage(PreferencesStorageBackend(prefs), prefs).write(
      const AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: '9876543210',
        displayName: kMockTeacherName,
        role: UserRole.teacher,
      ),
    );

    await notifier().resolveSession();

    expect(auth().isAuthenticated, isTrue);
    expect(auth().role, UserRole.teacher);
    expect(auth().displayName, kMockTeacherName);
  });

  test('selectChild updates active child for parent accounts', () async {
    await notifier().sendOtp('9876543210', UserRole.parent);
    await notifier().verifyOtp(kMockValidOtp);

    await notifier().selectChild(kMockLinkedChildren.last);

    expect(auth().selectedChild?.id, 'child-priya');

    final storage = AuthSessionStorage(PreferencesStorageBackend(prefs), prefs);
    final persisted = await storage.read();
    expect(persisted?.selectedChildId, 'child-priya');
  });

  test('logout clears persisted session', () async {
    await notifier().sendOtp('9876543210', UserRole.student);
    await notifier().verifyOtp(kMockValidOtp);
    await notifier().logout();

    expect(auth().status, AuthStatus.unauthenticated);

    final storage = AuthSessionStorage(PreferencesStorageBackend(prefs), prefs);
    expect(await storage.read(), isNull);
  });
}
