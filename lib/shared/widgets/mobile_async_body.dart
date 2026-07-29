import 'package:flutter/material.dart';

import '../async/erp_async_state.dart';
import 'akshara_empty_state.dart';
import 'akshara_error_state.dart';
import 'akshara_loading_state.dart';

/// Mobile dashboard async wrapper aligned with `ErpAsyncBody` semantics.
class MobileAsyncBody extends StatelessWidget {
  const MobileAsyncBody({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.isEmpty,
    required this.onRetry,
    required this.builder,
    this.loadingLabel,
    this.errorMessage = 'Unable to load dashboard right now.',
    this.emptyMessage = 'Nothing to show yet.',
    this.emptyIcon = Icons.dashboard_outlined,
    this.skeleton,
  });

  /// Honest-async contract entry point for a mobile persona dashboard.
  ///
  /// Derives loading / error / empty from the REAL [ErpViewState] produced by
  /// `resolveErpAsync`, so the screen can no longer read a manual
  /// `StateProvider<bool>` that production never writes (WIDGET-001 /
  /// WIDGET-002 root cause (1)).
  MobileAsyncBody.fromState(
    ErpViewState<Object?> state, {
    super.key,
    required this.onRetry,
    required this.builder,
    this.loadingLabel,
    String? errorMessage,
    this.emptyMessage = 'Nothing to show yet.',
    this.emptyIcon = Icons.dashboard_outlined,
    this.skeleton,
  })  : isLoading = state.isLoading,
        hasError = state.hasError,
        // A null payload is NEVER rendered as data — it is an honest empty.
        isEmpty = state.isEmpty || (!state.isLoading && !state.hasError && state.data == null),
        errorMessage = errorMessage ?? state.errorText;

  final bool isLoading;
  final bool hasError;
  final bool isEmpty;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context) builder;
  final String? loadingLabel;
  final String errorMessage;
  final String emptyMessage;
  final IconData emptyIcon;

  /// Optional content-shaped loading placeholder (see [AksharaSkeleton]);
  /// falls back to the centered spinner when null.
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return AksharaLoadingState(
        semanticLabel: loadingLabel ?? 'Loading',
        skeleton: skeleton,
      );
    }
    if (hasError) {
      return AksharaErrorState(message: errorMessage, onRetry: onRetry);
    }
    if (isEmpty) {
      return AksharaEmptyState(message: emptyMessage, icon: emptyIcon);
    }
    return builder(context);
  }
}
