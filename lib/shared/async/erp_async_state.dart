import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../widgets/akshara_empty_state.dart';
import '../widgets/akshara_error_state.dart';
import '../widgets/akshara_loading_state.dart';
import '../../theme/spacing.dart';

// ---------------------------------------------------------------------------
// THE HONEST-ASYNC CONTRACT  (Phase 1 · RC-1 · roadmap W1.1)
// ---------------------------------------------------------------------------
//
// One contract for every production surface that reads a repository:
//
//   * loading  renders a skeleton (or the standard spinner),
//   * error    renders an honest error with a retry,
//   * empty    renders an honest empty state,
//   * data     renders ONLY values the server actually issued.
//
// No path may substitute a demo, seeded or hard-coded business value. A
// provider that has no server payload returns either `null` or a *neutral*
// `.empty()` shape — a shape with no business values in it (no money, no
// attendance, no names, no counts). It never returns `X.mock()`, a
// `_fallbackFoo()` constant, or a "curated demo figure".
//
// The three moving parts, all pre-existing, are wired together here:
//
//   1. `resolveErpAsync` turns the real `AsyncValue` (plus the manual QA
//      override flags) into an `ErpViewState`. The manual flags are an
//      *override*, never the sole source — that inversion is exactly what let
//      a dead `StateProvider<bool>` hide the mock path (CERT-001, WIDGET-001,
//      WIDGET-002, JOURNEY-007).
//   2. `ErpAsyncBody` / `MobileAsyncBody.fromState` render that state through
//      `AksharaLoadingState` / `AksharaErrorState` / `AksharaEmptyState`.
//   3. `honestPayload` is the ONLY sanctioned way to turn a nullable payload
//      into a non-null one, and it takes a neutral empty shape — not a mock.
//
// The contract is mechanically enforced by
// `test/guards/honest_async_contract_guard_test.dart`.

/// Resolved UI state for an ERP async repository call.
@immutable
class ErpViewState<T> {
  const ErpViewState({
    this.isLoading = false,
    this.failure,
    this.isEmpty = false,
    this.data,
  });

  final bool isLoading;
  final ApiFailure? failure;
  final bool isEmpty;
  final T? data;

  bool get hasError => failure != null;

  /// True when the server issued a payload this frame.
  bool get hasData => data != null && !isLoading && !hasError;

  /// The message an honest error state should show for this failure.
  String get errorText => failure?.displayMessage ?? 'Unable to load data.';

  /// Re-wraps this state around a derived/adapted payload, preserving the
  /// loading / error / empty verdict. Used where a provider post-processes the
  /// server payload (capability adapters, active-child projection, …) — the
  /// adaptation must never resurrect a value the server did not issue.
  ErpViewState<R> mapData<R>(R Function(T data) transform) {
    final value = data;
    return ErpViewState<R>(
      isLoading: isLoading,
      failure: failure,
      isEmpty: isEmpty,
      data: value == null ? null : transform(value),
    );
  }
}

/// The ONLY sanctioned way to produce a non-null payload from an
/// [ErpViewState].
///
/// [neutralEmpty] must build a shape with **no business values** — the in-tree
/// reference implementations are `StudentDashboardData.empty()` and
/// `AttendanceMonthData.empty()`. Passing a `.mock()` / demo fixture here is a
/// contract violation and is rejected by the guard test.
T honestPayload<T>(ErpViewState<T> state, T Function() neutralEmpty) =>
    state.data ?? neutralEmpty();

/// Combines [AsyncValue] with manual test overrides into a view state.
ErpViewState<T> resolveErpAsync<T>(
  AsyncValue<T> async, {
  bool forceLoading = false,
  bool forceError = false,
  bool forceEmpty = false,
  String errorMessage = 'Unable to load data.',
  bool Function(T data)? isDataEmpty,
}) {
  if (forceLoading) {
    return const ErpViewState(isLoading: true);
  }
  if (forceError) {
    return ErpViewState(
      failure: ApiFailure(
        type: ApiFailureType.unknown,
        message: errorMessage,
        code: 'MANUAL_ERROR',
      ),
    );
  }

  return async.when(
    loading: () => const ErpViewState(isLoading: true),
    error: (error, _) => ErpViewState(
      failure: apiFailureMapper.fromException(error),
    ),
    data: (data) {
      final empty =
          forceEmpty || (isDataEmpty?.call(data) ?? _defaultIsEmpty(data));
      if (empty) {
        return ErpViewState<T>(isEmpty: true, data: data);
      }
      return ErpViewState(data: data);
    },
  );
}

bool _defaultIsEmpty<T>(T data) {
  if (data is List) return data.isEmpty;
  return false;
}

void retryErpFuture(WidgetRef ref, ProviderOrFamily provider) {
  ref.invalidate(provider);
}

/// Standard loading / error / empty / data body for ERP screens.
class ErpAsyncBody<T> extends StatelessWidget {
  const ErpAsyncBody({
    super.key,
    required this.state,
    required this.onRetry,
    required this.loadingLabel,
    required this.emptyMessage,
    required this.builder,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.skeleton,
  });

  final ErpViewState<T> state;
  final VoidCallback onRetry;
  final String loadingLabel;
  final String emptyMessage;
  final Widget Function(T data) builder;
  final IconData emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Optional content-shaped loading placeholder (see [AksharaSkeleton]);
  /// falls back to the centered spinner when null.
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      final skeleton = this.skeleton;
      if (skeleton != null) {
        return AksharaLoadingState(semanticLabel: loadingLabel, skeleton: skeleton);
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s6),
        child: AksharaLoadingState(semanticLabel: loadingLabel),
      );
    }

    if (state.failure != null) {
      return AksharaErrorState.fromFailure(
        state.failure!,
        onRetry: onRetry,
      );
    }

    if (state.isEmpty || state.data == null) {
      return AksharaEmptyState(
        message: emptyMessage,
        icon: emptyIcon,
        actionLabel: emptyActionLabel,
        onAction: onEmptyAction,
      );
    }

    return builder(state.data as T);
  }
}
