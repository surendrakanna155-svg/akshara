import 'package:akshara_erp/core/auth/secure_storage_backend.dart';
import 'package:akshara_erp/features/auth/auth_token_models.dart';
import 'package:akshara_erp/features/auth/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TokenStorage', () {
    test('persists and reads tokens via secure backend', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = TokenStorage(PreferencesStorageBackend(prefs));
      final tokens = AuthTokens.demo();

      await storage.write(tokens);
      final restored = await storage.read();

      expect(restored, tokens);
      expect(storage.readSync(), tokens);
    });

    test('clear removes persisted tokens', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = TokenStorage(PreferencesStorageBackend(prefs));
      await storage.write(AuthTokens.demo());
      await storage.clear();

      expect(await storage.read(), isNull);
      expect(storage.readSync(), isNull);
    });

    test('persists optional session metadata fields', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = TokenStorage(PreferencesStorageBackend(prefs));
      final tokens = AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        sessionId: 'session_1',
        refreshTokenId: 'rt_1',
        tokenFamilyId: 'family_1',
        deviceId: 'device_1',
      );

      await storage.write(tokens);
      final restored = await storage.read();

      expect(restored?.sessionId, 'session_1');
      expect(restored?.refreshTokenId, 'rt_1');
      expect(restored?.tokenFamilyId, 'family_1');
      expect(restored?.deviceId, 'device_1');
    });
  });
}
