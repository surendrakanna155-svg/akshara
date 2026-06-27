import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../auth/auth_models.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_token_provider.dart';
import 'legal_models.dart';
import 'legal_remote_data_source.dart';

/// Where the legal acceptance gate currently stands for the signed-in user.
enum LegalGatePhase {
  /// No signed-in user / not yet checked.
  unknown,

  /// A status request is in flight.
  loading,

  /// Nothing outstanding — the user may proceed.
  satisfied,

  /// The user must accept one or more policies before continuing.
  blocked,

  /// We could not determine status (network/endpoint error). Treated as
  /// non-blocking (fail-open) so an outage never traps users out of the app.
  error,
}

class LegalGateState {
  const LegalGateState({
    required this.phase,
    this.outstanding = const [],
    this.policies = const [],
    this.submitting = false,
  });

  const LegalGateState.unknown()
      : phase = LegalGatePhase.unknown,
        outstanding = const [],
        policies = const [],
        submitting = false;

  final LegalGatePhase phase;

  /// Policies still to be accepted at the current version.
  final List<LegalPolicy> outstanding;

  /// All policies that apply to this user (for the review screen).
  final List<LegalPolicy> policies;

  /// True while an accept request is being submitted.
  final bool submitting;

  /// Only `blocked` blocks navigation. Loading/error/unknown are fail-open.
  bool get isBlocked => phase == LegalGatePhase.blocked;

  LegalGateState copyWith({
    LegalGatePhase? phase,
    List<LegalPolicy>? outstanding,
    List<LegalPolicy>? policies,
    bool? submitting,
  }) {
    return LegalGateState(
      phase: phase ?? this.phase,
      outstanding: outstanding ?? this.outstanding,
      policies: policies ?? this.policies,
      submitting: submitting ?? this.submitting,
    );
  }
}

class LegalGateController extends Notifier<LegalGateState> {
  LegalRemoteDataSource get _dataSource =>
      ref.read(legalRemoteDataSourceProvider);

  String? get _deviceId => ref.read(authTokensProvider)?.deviceId;

  @override
  LegalGateState build() => const LegalGateState.unknown();

  /// Fetches the latest status from the backend. Fail-open on any error.
  Future<void> refresh() async {
    state = state.copyWith(phase: LegalGatePhase.loading);
    try {
      _applyStatus(await _dataSource.fetchStatus());
    } catch (_) {
      // The endpoint may not be deployed yet, or the network may be down. Do not
      // block the user — re-check on the next launch.
      state = state.copyWith(phase: LegalGatePhase.error, submitting: false);
    }
  }

  /// Records acceptance of everything currently outstanding. Returns true when
  /// the user is fully satisfied afterwards.
  Future<bool> acceptOutstanding() async {
    final pending = state.outstanding;
    if (pending.isEmpty) return true;
    state = state.copyWith(submitting: true);
    try {
      _applyStatus(
        await _dataSource.accept(policies: pending, deviceId: _deviceId),
      );
      return state.phase == LegalGatePhase.satisfied;
    } catch (_) {
      state = state.copyWith(submitting: false);
      return false;
    }
  }

  /// Clears state on logout.
  void reset() => state = const LegalGateState.unknown();

  void _applyStatus(LegalStatus status) {
    state = LegalGateState(
      phase: status.satisfied
          ? LegalGatePhase.satisfied
          : LegalGatePhase.blocked,
      outstanding: status.outstanding,
      policies: status.policies,
      submitting: false,
    );
  }
}

/// Remote data source (overridable in tests).
final legalRemoteDataSourceProvider = Provider<LegalRemoteDataSource>((ref) {
  return LegalRemoteDataSource(ref.watch(dioProvider));
});

/// The legal gate state for the signed-in user.
final legalGateProvider =
    NotifierProvider<LegalGateController, LegalGateState>(
  LegalGateController.new,
);

/// Whether navigation should currently be blocked pending acceptance. The router
/// reads this; it is true ONLY when the backend positively reported outstanding
/// mandatory policies.
final legalGateBlockedProvider = Provider<bool>((ref) {
  return ref.watch(legalGateProvider).isBlocked;
});

/// Keeps the legal gate in sync with the auth lifecycle: loads status on login,
/// resets on logout. Instantiated by the router provider so it stays alive.
final legalGateSyncProvider = Provider<void>((ref) {
  ref.listen<AuthState>(authProvider, (prev, next) {
    final wasAuthed = prev?.isAuthenticated ?? false;
    if (next.isAuthenticated && !wasAuthed) {
      ref.read(legalGateProvider.notifier).refresh();
    } else if (!next.isAuthenticated && wasAuthed) {
      ref.read(legalGateProvider.notifier).reset();
    }
  });

  // Already signed in at construction (e.g. a restored session at cold start).
  final current = ref.read(authProvider);
  if (current.isAuthenticated) {
    Future.microtask(() => ref.read(legalGateProvider.notifier).refresh());
  }
});
