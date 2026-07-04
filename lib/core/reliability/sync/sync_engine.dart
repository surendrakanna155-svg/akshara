import 'dart:async';
import 'dart:math' as math;

import '../connectivity/connectivity_service.dart';
import '../model/mutation_envelope.dart';
import '../model/mutation_request.dart';
import '../model/operation_policy.dart';
import '../model/reliability_enums.dart';
import '../policy/operation_policy_registry.dart';
import '../store/reliability_store.dart';
import 'backoff.dart';
import 'conflict_resolver.dart';
import 'mutation_executor.dart';
import 'reliability_clock.dart';
import 'send_classification.dart';

/// Drains the outbox: sends each queued write with its idempotency key, then
/// transitions it by the server response (confirmed / conflict / failed /
/// retry-with-backoff). Triggered on reconnect and on demand (manual retry).
class SyncEngine {
  SyncEngine({
    required ReliabilityStore store,
    required MutationExecutor executor,
    required ConnectivityService connectivity,
    required OperationPolicyRegistry registry,
    this.backoff = const Backoff(),
    this.conflictResolver = const ConflictResolver(),
    ReliabilityClock clock = const SystemReliabilityClock(),
    math.Random? random,
  })  : _store = store,
        _executor = executor,
        _connectivity = connectivity,
        _registry = registry,
        _clock = clock,
        _random = random ?? math.Random();

  final ReliabilityStore _store;
  final MutationExecutor _executor;
  final ConnectivityService _connectivity;
  final OperationPolicyRegistry _registry;
  final Backoff backoff;
  final ConflictResolver conflictResolver;
  final ReliabilityClock _clock;
  final math.Random _random;

  StreamSubscription<bool>? _connSub;
  bool _draining = false;

  /// Begin reacting to connectivity changes. Call [flush] directly in tests.
  void start() {
    _connSub ??= _connectivity.onStatusChange.listen((bool online) {
      if (online) {
        // Fire and forget; flush guards against concurrency.
        unawaited(flush());
      }
    });
    // REL-4: a relaunch while already-online fires no connectivity *transition*,
    // so writes queued by a previous (killed) session would sit undrained. Drain
    // once on boot when online. (Offline boot is a no-op — the executor throws
    // and ops stay pending until the next reconnect.)
    if (_connectivity.isOnline) {
      unawaited(flush());
    }
  }

  /// REL-4: drain on app-resume when online (foregrounding after a background
  /// kill/offline stint). Safe to call anytime — re-entrant and no-op offline.
  void flushIfOnline() {
    if (_connectivity.isOnline) {
      unawaited(flush());
    }
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
    _connSub = null;
  }

  /// Process all due pending operations once. Re-entrant-safe.
  Future<void> flush() async {
    if (_draining) return;
    _draining = true;
    try {
      final List<MutationEnvelope> pending = await _store.pendingOperations();
      final DateTime now = _clock.now();
      for (final MutationEnvelope op in pending) {
        final DateTime? next = op.nextAttemptAt;
        if (next != null && next.isAfter(now)) {
          continue; // backoff not yet elapsed
        }
        await _process(op);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _process(MutationEnvelope op) async {
    await _store.putOperation(op.copyWith(status: SyncStatus.inFlight));
    try {
      final ExecutorResponse resp = await _executor.send(op.request);
      switch (classifyResponse(resp)) {
        case SendClassification.confirmed:
          await _store.putOperation(
            op.copyWith(status: SyncStatus.confirmed, clearNextAttemptAt: true),
          );
        case SendClassification.conflict:
          await _onConflict(op, resp.data);
        case SendClassification.failed:
          await _store.putOperation(
            op.copyWith(
              status: SyncStatus.failed,
              lastError: resp.errorCode,
              clearNextAttemptAt: true,
            ),
          );
        case SendClassification.transient:
          await _scheduleRetry(op, resp.errorCode);
      }
    } on NetworkUnavailableException {
      await _scheduleRetry(op, 'OFFLINE');
    }
  }

  Future<void> _onConflict(
    MutationEnvelope op,
    Map<String, dynamic>? serverRow,
  ) async {
    final OperationPolicy policy = _registry.policyFor(op.request.type);
    switch (conflictResolver.resolve(policy.conflictCategory)) {
      case ConflictResolution.retryWithServerVersion:
        // Low-risk last-write-wins: re-apply carrying the server version as a
        // precondition so the server accepts the overwrite on the next drain.
        final MutationRequest next = _withServerVersion(op.request, serverRow);
        final int attempts = op.attempts + 1;
        await _store.putOperation(
          op.copyWith(
            request: next,
            status: SyncStatus.pending,
            attempts: attempts,
            serverRow: serverRow,
            nextAttemptAt:
                _clock.now().add(backoff.delayFor(attempts, random: _random)),
          ),
        );
      case ConflictResolution.requireUserResolution:
        // High-risk: park for explicit user resolution; never auto-overwrite.
        await _store.putOperation(
          op.copyWith(
            status: SyncStatus.conflict,
            serverRow: serverRow,
            clearNextAttemptAt: true,
          ),
        );
    }
  }

  Future<void> _scheduleRetry(MutationEnvelope op, String? error) async {
    final int attempts = op.attempts + 1;
    if (!backoff.shouldRetry(attempts)) {
      await _store.putOperation(
        op.copyWith(
          status: SyncStatus.failed,
          attempts: attempts,
          lastError: error ?? 'RETRY_EXHAUSTED',
          clearNextAttemptAt: true,
        ),
      );
      return;
    }
    await _store.putOperation(
      op.copyWith(
        status: SyncStatus.pending,
        attempts: attempts,
        lastError: error,
        nextAttemptAt:
            _clock.now().add(backoff.delayFor(attempts, random: _random)),
      ),
    );
  }

  /// Re-submit a high-risk-rejected low-risk write with the server's current
  /// version as a precondition (`expectedVersion`), enabling a safe overwrite.
  MutationRequest _withServerVersion(
    MutationRequest request,
    Map<String, dynamic>? serverRow,
  ) {
    final Object? version = serverRow?['row_version'] ??
        serverRow?['rowVersion'] ??
        serverRow?['updated_at'];
    if (version == null) return request;
    return request.copyWith(
      body: <String, dynamic>{...request.body, 'expectedVersion': version},
    );
  }

  /// Force a user-resolved high-risk conflict back into the queue. [keepClient]
  /// re-applies the user's copy with the server precondition; otherwise the
  /// operation is dropped (user accepted the server copy).
  Future<void> resolveConflict(String operationId,
      {required bool keepClient}) async {
    final MutationEnvelope? op = await _store.getOperation(operationId);
    if (op == null || op.status != SyncStatus.conflict) return;
    if (!keepClient) {
      await _store.deleteOperation(operationId);
      return;
    }
    final MutationRequest next = _withServerVersion(op.request, op.serverRow);
    await _store.putOperation(
      op.copyWith(
        request: next,
        status: SyncStatus.pending,
        clearNextAttemptAt: true,
      ),
    );
  }

  /// Manual "retry now" from the Sync Center: reset any failed/parked ops to
  /// pending and drain immediately.
  Future<void> retryAllNow() async {
    final List<MutationEnvelope> all = await _store.allOperations();
    for (final MutationEnvelope op in all) {
      if (op.status == SyncStatus.failed) {
        await _store.putOperation(
          op.copyWith(status: SyncStatus.pending, clearNextAttemptAt: true),
        );
      }
    }
    await flush();
  }
}
