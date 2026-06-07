import 'package:akshara_erp/core/auth/refresh_token_rotation_tracker.dart';
import 'package:akshara_erp/features/auth/auth_token_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RefreshTokenRotationTracker', () {
    late RefreshTokenRotationTracker tracker;

    setUp(() => tracker = RefreshTokenRotationTracker());

    AuthTokens tokens({
      required String refresh,
      String family = 'family_1',
    }) {
      return AuthTokens(
        accessToken: 'access_$refresh',
        refreshToken: refresh,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        tokenFamilyId: family,
      );
    }

    test('seeds initial refresh token', () {
      final initial = tokens(refresh: 'refresh_a');
      tracker.seed(initial);

      expect(tracker.activeRefreshTokenHash, isNotNull);
      expect(tracker.detectReuse(initial), isFalse);
    });

    test('records rotation and marks spent token as reuse', () {
      final first = tokens(refresh: 'refresh_a');
      final second = tokens(refresh: 'refresh_b');

      tracker.seed(first);
      final rotation = tracker.recordRotation(previous: first, next: second);

      expect(rotation.status, RefreshRotationStatus.rotated);
      expect(tracker.detectReuse(first), isTrue);
      expect(tracker.detectReuse(second), isFalse);
    });

    test('detects reuse before rotation is recorded', () {
      final first = tokens(refresh: 'refresh_a');
      final second = tokens(refresh: 'refresh_b');

      tracker.seed(first);
      tracker.recordRotation(previous: first, next: second);

      expect(tracker.detectReuse(first), isTrue);
    });

    test('reset clears rotation state', () {
      final initial = tokens(refresh: 'refresh_a');
      tracker.seed(initial);
      tracker.reset();

      expect(tracker.activeRefreshTokenHash, isNull);
      expect(tracker.detectReuse(initial), isFalse);
    });
  });
}
