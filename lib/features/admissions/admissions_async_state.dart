import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../shared/widgets/akshara_empty_state.dart';
import '../../shared/widgets/akshara_error_state.dart';
import '../../shared/widgets/akshara_loading_state.dart';

/// Resolved UI state for an admissions async repository call.
@immutable
class AdmissionsViewState<T> {
  const AdmissionsViewState({
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
}

/// Combines [AsyncValue] with manual test overrides into a view state.
AdmissionsViewState<T> resolveAdmissionsAsync<T>(
  AsyncValue<T> async, {
  bool forceLoading = false,
  bool forceError = false,
  bool forceEmpty = false,
  bool Function(T data)? isDataEmpty,
}) {
  if (forceLoading) {
    return const AdmissionsViewState(isLoading: true);
  }
  if (forceError) {
    return const AdmissionsViewState(
      failure: ApiFailure(
        type: ApiFailureType.unknown,
        message: 'Unable to load admissions data.',
        code: 'MANUAL_ERROR',
      ),
    );
  }

  return async.when(
    loading: () => const AdmissionsViewState(isLoading: true),
    error: (error, _) => AdmissionsViewState(
      failure: apiFailureMapper.fromException(error),
    ),
    data: (data) {
      final empty =
          forceEmpty || (isDataEmpty?.call(data) ?? _defaultIsEmpty(data));
      if (empty) {
        return AdmissionsViewState<T>(isEmpty: true, data: data);
      }
      return AdmissionsViewState(data: data);
    },
  );
}

bool _defaultIsEmpty<T>(T data) {
  if (data is List) return data.isEmpty;
  return false;
}

/// Invalidates a [FutureProvider] to trigger retry.
void retryAdmissionsFuture(WidgetRef ref, ProviderOrFamily provider) {
  ref.invalidate(provider);
}

/// Standard loading / error / empty / data body for admissions screens.
class AdmissionsAsyncBody<T> extends StatelessWidget {
  const AdmissionsAsyncBody({
    super.key,
    required this.state,
    required this.onRetry,
    required this.loadingLabel,
    required this.emptyMessage,
    required this.builder,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final AdmissionsViewState<T> state;
  final VoidCallback onRetry;
  final String loadingLabel;
  final String emptyMessage;
  final Widget Function(T data) builder;
  final IconData emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
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
