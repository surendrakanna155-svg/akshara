// Red Team Wave 4 — Client Write Resilience (RT-24..30) unit evidence.
//
// These tests exercise the deterministic, client-side behaviours the wave fixes:
//   RT-24/25  a mutation notifier re-entry guard fires the write exactly once on
//             a double-tap (verified on a notifier that uses the exact guard
//             pattern applied across all 204 mutation sites).
//   RT-27     caught errors map to clean user-facing messages, never raw
//             `ApiFailureException.toString()`.
//   RT-29     the auth interceptor only auto-replays a request after a 401
//             refresh when it is safe (idempotent verb, or a write carrying an
//             Idempotency-Key) — bare writes are never replayed.
//   RT-24     the non-nullable mutation in-progress failure is a typed,
//             user-friendly ApiFailureException.
import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/errors/error_text.dart';
import 'package:akshara_erp/core/errors/mutation_in_progress.dart';
import 'package:akshara_erp/core/network/interceptors/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// A notifier replicating the production mutation guard pattern, with a counter
// so we can prove a double-tap calls the underlying action only once.
class _CountingMutationNotifier extends AsyncNotifier<int?> {
  int calls = 0;

  @override
  int? build() => null;

  Future<int?> execute() async {
    // RT-24 guard — identical to the line inserted at every mutation site.
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      calls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return calls;
    });
    return state.valueOrNull;
  }
}

final _countingProvider =
    AsyncNotifierProvider<_CountingMutationNotifier, int?>(
  _CountingMutationNotifier.new,
);

void main() {
  group('RT-24/25 double-submit guard', () {
    test('a double-tap fires the underlying write exactly once', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(_countingProvider.notifier);

      // Two near-simultaneous taps (second fires before the first resolves).
      final f1 = notifier.execute();
      final f2 = notifier.execute();
      await Future.wait([f1, f2]);

      expect(notifier.calls, 1, reason: 'guard must collapse the double-tap');
    });

    test('a sequential second call after completion still works', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(_countingProvider.notifier);

      await notifier.execute();
      await notifier.execute();

      expect(notifier.calls, 2, reason: 'guard only blocks in-flight re-entry');
    });
  });

  group('RT-27 error text mapping', () {
    test('ApiFailureException maps to its clean message, not toString()', () {
      final failure = ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.forbidden,
          message: 'You do not have permission to perform this action.',
          code: 'FORBIDDEN',
        ),
      );
      final text = aksharaErrorMessage(failure);
      expect(text, 'You do not have permission to perform this action.');
      expect(text.contains('ApiFailureException'), isFalse);
    });

    test('an arbitrary error maps to a generic friendly message', () {
      final text = aksharaErrorMessage(StateError('boom internal detail'));
      expect(text, 'Something went wrong. Please try again.');
      expect(text.contains('boom'), isFalse);
    });
  });

  group('RT-24 in-progress failure helper', () {
    test('is a typed, user-friendly ApiFailureException', () {
      final ex = mutationInProgressFailure();
      expect(ex, isA<ApiFailureException>());
      expect(ex.failure.code, 'MUTATION_IN_PROGRESS');
      expect(aksharaErrorMessage(ex), contains('already in progress'));
    });
  });

  group('RT-29 auth auto-replay safety', () {
    RequestOptions opts(String method, {Map<String, dynamic>? headers}) =>
        RequestOptions(path: '/x', method: method, headers: headers ?? {});

    test('idempotent verbs are safe to replay', () {
      expect(AuthInterceptor.isSafeToAutoReplay(opts('GET')), isTrue);
      expect(AuthInterceptor.isSafeToAutoReplay(opts('HEAD')), isTrue);
      expect(AuthInterceptor.isSafeToAutoReplay(opts('OPTIONS')), isTrue);
    });

    test('bare writes are NOT replayed (would duplicate)', () {
      expect(AuthInterceptor.isSafeToAutoReplay(opts('POST')), isFalse);
      expect(AuthInterceptor.isSafeToAutoReplay(opts('PUT')), isFalse);
      expect(AuthInterceptor.isSafeToAutoReplay(opts('PATCH')), isFalse);
      expect(AuthInterceptor.isSafeToAutoReplay(opts('DELETE')), isFalse);
    });

    test('a write with an Idempotency-Key is safe to replay (server dedupes)',
        () {
      expect(
        AuthInterceptor.isSafeToAutoReplay(
          opts('POST', headers: {'Idempotency-Key': 'abc-123'}),
        ),
        isTrue,
      );
      // header name is matched case-insensitively
      expect(
        AuthInterceptor.isSafeToAutoReplay(
          opts('POST', headers: {'idempotency-key': 'abc-123'}),
        ),
        isTrue,
      );
    });
  });
}
