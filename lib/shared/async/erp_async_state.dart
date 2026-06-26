import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../widgets/akshara_empty_state.dart';
import '../widgets/akshara_error_state.dart';
import '../widgets/akshara_loading_state.dart';
import '../../theme/spacing.dart';

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
}

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
  });

  final ErpViewState<T> state;
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
