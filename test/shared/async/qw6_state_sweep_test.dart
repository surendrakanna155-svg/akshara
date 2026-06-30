import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/shared/async/erp_async_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_empty_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_loading_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW6 · QA-X-018 / QA-X-019 — systematic state-behaviour sweep.
///
/// Every ERP list/detail screen renders its loading / error / empty / data state
/// through ONE canonical component, [ErpAsyncBody] (fed by [resolveErpAsync]).
/// Rather than re-pumping every screen (already partly covered by the per-module
/// `*_screens_test.dart`), this sweeps that single seam so the canonical
/// `AksharaLoading / AksharaError / AksharaEmptyState` contract holds for all of
/// them at once — and proves errors surface a recoverable, mapped message
/// (never a raw exception / stack), with a retry affordance when retryable.
void main() {
  Future<void> pumpBody(
    WidgetTester tester, {
    required ErpViewState<List<String>> state,
    VoidCallback? onRetry,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: ErpAsyncBody<List<String>>(
            state: state,
            onRetry: onRetry ?? () {},
            loadingLabel: 'Loading registry',
            emptyMessage: 'No students yet',
            builder: (List<String> data) =>
                Column(children: <Widget>[for (final String d in data) Text(d)]),
          ),
        ),
      ),
    );
    // Not pumpAndSettle: the loading state's CircularProgressIndicator animates
    // forever. Advance past the one-shot entrance animation only.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('QA-X-018 · canonical state widgets per ErpAsyncBody state', () {
    testWidgets('loading → AksharaLoadingState', (tester) async {
      await pumpBody(tester,
          state: const ErpViewState<List<String>>(isLoading: true));
      expect(find.byType(AksharaLoadingState), findsOneWidget);
      expect(find.byType(AksharaErrorState), findsNothing);
      expect(find.byType(AksharaEmptyState), findsNothing);
    });

    testWidgets('error → AksharaErrorState', (tester) async {
      await pumpBody(tester,
          state: const ErpViewState<List<String>>(
            failure: ApiFailure(
                type: ApiFailureType.server,
                message: 'Server error. Our team has been notified.',
                code: 'SERVER_ERROR'),
          ));
      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(find.byType(AksharaLoadingState), findsNothing);
    });

    testWidgets('empty → AksharaEmptyState with the empty message', (tester) async {
      await pumpBody(tester,
          state: const ErpViewState<List<String>>(isEmpty: true));
      expect(find.byType(AksharaEmptyState), findsOneWidget);
      expect(find.textContaining('No students yet'), findsOneWidget);
    });

    testWidgets('data → builder output', (tester) async {
      await pumpBody(tester,
          state: const ErpViewState<List<String>>(data: <String>['Alice', 'Bob']));
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.byType(AksharaEmptyState), findsNothing);
    });
  });

  group('QA-X-018 · resolveErpAsync maps AsyncValue + overrides', () {
    test('loading / error / data / empty-list', () {
      expect(
          resolveErpAsync<List<String>>(const AsyncLoading<List<String>>())
              .isLoading,
          isTrue);
      expect(
          resolveErpAsync<List<String>>(
                  AsyncError<List<String>>(Exception('x'), StackTrace.empty))
              .hasError,
          isTrue);
      final data = resolveErpAsync<List<String>>(
          const AsyncData<List<String>>(<String>['a']));
      expect(data.data, <String>['a']);
      expect(data.isEmpty, isFalse);
      // A successful-but-empty collection resolves to the empty state.
      expect(
          resolveErpAsync<List<String>>(const AsyncData<List<String>>(<String>[]))
              .isEmpty,
          isTrue);
    });

    test('force overrides win regardless of the AsyncValue', () {
      final loading = resolveErpAsync<List<String>>(
          const AsyncData<List<String>>(<String>['a']),
          forceLoading: true);
      expect(loading.isLoading, isTrue);
      final error = resolveErpAsync<List<String>>(
          const AsyncData<List<String>>(<String>['a']),
          forceError: true);
      expect(error.hasError, isTrue);
      final empty = resolveErpAsync<List<String>>(
          const AsyncData<List<String>>(<String>['a']),
          forceEmpty: true);
      expect(empty.isEmpty, isTrue);
    });
  });

  group('QA-X-019 · errors surface a mapped message, never a raw exception', () {
    testWidgets('a raw exception is mapped — no stack/raw text leaks to the UI',
        (tester) async {
      const String sentinel = 'RAW_LEAK_SENTINEL_8675309';
      final ErpViewState<List<String>> state = resolveErpAsync<List<String>>(
        AsyncError<List<String>>(Exception(sentinel), StackTrace.empty),
      );
      await pumpBody(tester, state: state);

      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(find.textContaining(sentinel), findsNothing,
          reason: 'the raw exception text must never reach the UI');
      expect(find.textContaining('Something went wrong'), findsWidgets,
          reason: 'a safe, user-facing message is shown instead');
    });

    testWidgets('a retryable failure shows a working retry affordance',
        (tester) async {
      int retries = 0;
      await pumpBody(
        tester,
        state: const ErpViewState<List<String>>(
          failure: ApiFailure(
              type: ApiFailureType.network,
              message: 'Unable to reach the server. Check your network connection.',
              code: 'NETWORK'),
        ),
        onRetry: () => retries++,
      );

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(retries, 1, reason: 'tapping retry re-runs the provider');
    });

    testWidgets('a non-retryable failure (forbidden) shows NO retry button',
        (tester) async {
      await pumpBody(
        tester,
        state: const ErpViewState<List<String>>(
          failure: ApiFailure(
              type: ApiFailureType.forbidden,
              message: 'You do not have permission to perform this action.',
              code: 'FORBIDDEN'),
        ),
      );
      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(find.text('Try again'), findsNothing,
          reason: 'a permission error is not resolved by retrying');
    });
  });
}
