import 'package:akshara_erp/core/auth/token_refresh_service.dart';
import 'package:akshara_erp/features/auth/auth_token_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TokenRefreshService', () {
    late TokenRefreshService service;

    setUp(() {
      service = TokenRefreshService();
    });

    tearDown(() => service.dispose());

    test('refreshes expired tokens via callback', () async {
      final expired = AuthTokens(
        accessToken: 'expired',
        refreshToken: 'refresh_1',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      final outcome = await service.refreshIfNeeded(
        tokens: expired,
        refreshCallback: (_) async => AuthTokens.demo(),
      );

      expect(outcome.status, TokenRefreshStatus.refreshed);
      expect(outcome.tokens, isNotNull);
      expect(outcome.tokens!.isExpired, isFalse);
    });

    test('schedules refresh before expiry', () async {
      var triggered = false;
      service.scheduleRefresh(
        tokens: AuthTokens.demo(ttl: const Duration(milliseconds: 200)),
        onRefreshDue: () async => triggered = true,
        leadTime: const Duration(milliseconds: 50),
      );

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(triggered, isTrue);
    });
  });
}
