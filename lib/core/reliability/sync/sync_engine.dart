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
      // REL-9 — gate the drain on a REAL reachability probe, not just the OS
      // interface flag: behind a captive portal the interface is "online" but no
      // write can land, so skip the drain (queued ops stay pending) rather than
      // burn attempts + backoff. Fails open, so it never wrongly blocks a drain.
      if (!await _connectivity.isReachable()) return;
      // REL-6 — crash-safe dequeue: before reading the queue, reclaim any op a
      // prior run (or an unexpected throw this session) stranded `inFlight` back
      // to `pending`. The single-flight `_draining` guard means no op is mid-send
      // right now, so this only ever recovers orphans — never a live claim.
      await _store.reclaimInFlightOperations();
      final List<MutationEnvelope> pending = await _store.pendingOperations();
      final DateTime now = _clock.now();
      // REL-9 — per-entity ordering: writes for the SAME entity must apply in
      // submission order. `pendingOperations()` is oldest-first; once an op for
      // an entity does NOT confirm this drain (backoff-deferred, retried,
      // conflicted or failed), every LATER op for that same entity is held until
      // the earlier one clears — so a newer edit can never overtake an older one.
      final Set<String> blockedEntities = <String>{};
      for (final MutationEnvelope op in pending) {
        final String? entity = op.request.entityRef;
        if (entity != null && blockedEntities.contains(entity)) {
          continue; // an earlier write for this entity is still outstanding
        }
        final DateTime? next = op.nextAttemptAt;
        if (next != null && next.isAfter(now)) {
          if (entity != null) blockedEntities.add(entity);
          continue; // backoff not yet elapsed → hold this + later same-entity ops
        }
        final SyncStatus result = await _process(op);
        if (result != SyncStatus.confirmed && entity != null) {
          blockedEntities.add(entity);
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// Send one op and transition it; returns the resulting [SyncStatus] so the
  /// drain can enforce per-entity ordering (REL-9).
  Future<SyncStatus> _process(MutationEnvelope op) async {
    await _store.putOperation(op.copyWith(status: SyncStatus.inFlight));
    try {
      final ExecutorResponse resp = await _executor.send(op.request);
      switch (classifyResponse(resp)) {
        case SendClassification.confirmed:
          await _store.putOperation(
            op.copyWith(status: SyncStatus.confirmed, clearNextAttemptAt: true),
          );
          return SyncStatus.confirmed;
        case SendClassification.conflict:
          await _onConflict(op, resp.data);
          return SyncStatus.conflict;
        case SendClassification.failed:
          await _store.putOperation(
            op.copyWith(
              status: SyncStatus.failed,
              lastError: resp.errorCode,
              clearNextAttemptAt: true,
            ),
          );
          return SyncStatus.failed;
        case SendClassification.transient:
          await _scheduleRetry(op, resp.errorCode);
          return SyncStatus.pending;
      }
    } on NetworkUnavailableException {
      await _scheduleRetry(op, 'OFFLINE');
      return SyncStatus.pending;
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
