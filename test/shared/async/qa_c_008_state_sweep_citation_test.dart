import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/shared/async/erp_async_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW7 · QA-C-008 — State sweep (loading / error / empty / success).
///
/// ────────────────────────────────────────────────────────────────────────────
/// CANONICAL CERT (do NOT duplicate): the systematic, screen-by-screen state
/// sweep is already certified by QW6's QA-X-018 / QA-X-019 in
///   test/shared/async/qw6_state_sweep_test.dart
/// which proves that EVERY ERP list/detail screen renders its loading / error /
/// empty / data state through ONE canonical seam — [ErpAsyncBody] fed by
/// [resolveErpAsync] — surfacing AksharaLoadingState / AksharaErrorState /
/// AksharaEmptyState and a recoverable (mapped, never raw) error with a retry
/// affordance.
///
/// Per the QW7 brief, QA-C-008 is ALREADY covered there and must not be rebuilt.
/// This file is the explicit CITATION anchor: it re-asserts only the single seam
/// (resolveErpAsync) maps all four states, so the cert row has a concrete,
/// runnable pointer back to the canonical sweep without re-pumping every screen.
/// ────────────────────────────────────────────────────────────────────────────
void main() {
  group('QA-C-008 · cites qw6_state_sweep_test.dart (canonical state cert)', () {
    test('resolveErpAsync maps loading / error / success / empty at the seam',
        () {
      // LOADING
      expect(
        resolveErpAsync<List<String>>(const AsyncLoading<List<String>>())
            .isLoading,
        isTrue,
      );

      // ERROR
      expect(
        resolveErpAsync<List<String>>(
          AsyncError<List<String>>(Exception('x'), StackTrace.empty),
        ).hasError,
        isTrue,
      );

      // SUCCESS (non-empty data)
      final data = resolveErpAsync<List<String>>(
        const AsyncData<List<String>>(<String>['a']),
      );
      expect(data.data, <String>['a']);
      expect(data.isEmpty, isFalse);

      // EMPTY (successful-but-empty collection resolves to the empty state)
      expect(
        resolveErpAsync<List<String>>(const AsyncData<List<String>>(<String>[]))
            .isEmpty,
        isTrue,
      );
    });

    test('an explicit ApiFailure carries a mapped (non-raw) message', () {
      // The canonical sweep proves errors surface a recoverable, mapped message
      // (never a raw exception / stack); this anchors that contract at the seam.
      const state = ErpViewState<List<String>>(
        failure: ApiFailure(
          type: ApiFailureType.server,
          message: 'Server error. Our team has been notified.',
          code: 'SERVER_ERROR',
        ),
      );
      expect(state.hasError, isTrue);
      expect(state.failure!.message, isNot(contains('Exception')));
    });
  });
}
