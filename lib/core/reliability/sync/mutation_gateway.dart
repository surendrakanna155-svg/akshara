import '../model/mutation_envelope.dart';
import '../model/mutation_outcome.dart';
import '../model/mutation_request.dart';
import '../model/operation_policy.dart';
import '../model/reliability_enums.dart';
import '../policy/operation_policy_registry.dart';
import '../store/reliability_store.dart';
import '../connectivity/connectivity_service.dart';
import 'mutation_executor.dart';
import 'reliability_clock.dart';
import 'send_classification.dart';

/// The single, universal choke point every write passes through (refinement R4).
///
/// It assigns/uses the operation's `Idempotency-Key`, consults the
/// [OperationPolicyRegistry], and routes the write online-vs-queue. No per-screen
/// offline code exists anywhere — behaviour is entirely policy-driven.
class MutationGateway {
  MutationGateway({
    required OperationPolicyRegistry registry,
    required MutationExecutor executor,
    required ReliabilityStore store,
    required ConnectivityService connectivity,
    ReliabilityClock clock = const SystemReliabilityClock(),
    void Function()? onQueued,
  })  : _registry = registry,
        _executor = executor,
        _store = store,
        _connectivity = connectivity,
        _clock = clock,
        _onQueued = onQueued;

  final OperationPolicyRegistry _registry;
  final MutationExecutor _executor;
  final ReliabilityStore _store;
  final ConnectivityService _connectivity;
  final ReliabilityClock _clock;
  final void Function()? _onQueued;

  Future<MutationOutcome> execute(MutationRequest request) async {
    final OperationPolicy policy = _registry.policyFor(request.type);

    if (policy.isOnlineOnly) {
      return _executeOnlineOnly(request);
    }
    // queueable (draftOnly never reaches the gateway — it is held by the
    // DraftController until the user submits, at which point it becomes a
    // normal queueable/online write).
    return _executeQueueable(request, policy);
  }

  Future<MutationOutcome> _executeOnlineOnly(MutationRequest request) async {
    try {
      final ExecutorResponse resp = await _executor.send(request);
      switch (classifyResponse(resp)) {
        case SendClassification.confirmed:
          return MutationOutcome(
            status: SyncStatus.confirmed,
            operationId: request.idempotencyKey,
            data: resp.data,
          );
        case SendClassification.conflict:
          return MutationOutcome(
            status: SyncStatus.conflict,
            operationId: request.idempotencyKey,
            serverRow: resp.data,
            errorCode: resp.errorCode,
          );
        case SendClassification.failed:
        case SendClassification.transient:
          return MutationOutcome(
            status: SyncStatus.failed,
            operationId: request.idempotencyKey,
            errorCode: resp.errorCode,
            errorMessage: resp.errorMessage,
          );
      }
    } on NetworkUnavailableException {
      // Online-only writes are NOT queued — they fail fast and clearly.
      return MutationOutcome(
        status: SyncStatus.failed,
        operationId: request.idempotencyKey,
        errorCode: 'OFFLINE',
        errorMessage: 'No connection. This action needs to be online.',
      );
    }
  }

  Future<MutationOutcome> _executeQueueable(
    MutationRequest request,
    OperationPolicy policy,
  ) async {
    if (!_connectivity.isOnline) {
      return _enqueuePending(request);
    }
    try {
      final ExecutorResponse resp = await _executor.send(request);
      switch (classifyResponse(resp)) {
        case SendClassification.confirmed:
          await _store.putOperation(
            MutationEnvelope(
              request: request,
              status: SyncStatus.confirmed,
              createdAt: _clock.now(),
            ),
          );
          return MutationOutcome(
            status: SyncStatus.confirmed,
            operationId: request.idempotencyKey,
            data: resp.data,
          );
        case SendClassification.conflict:
          if (policy.requiresExplicitConflictResolution) {
            await _store.putOperation(
              MutationEnvelope(
                request: request,
                status: SyncStatus.conflict,
                createdAt: _clock.now(),
                serverRow: resp.data,
              ),
            );
            return MutationOutcome(
              status: SyncStatus.conflict,
              operationId: request.idempotencyKey,
              serverRow: resp.data,
              errorCode: resp.errorCode,
            );
          }
          // low-risk → let the engine re-apply (LWW) on the next drain.
          return _enqueuePending(request, serverRow: resp.data);
        case SendClassification.failed:
          await _store.putOperation(
            MutationEnvelope(
              request: request,
              status: SyncStatus.failed,
              createdAt: _clock.now(),
              lastError: resp.errorCode,
            ),
          );
          return MutationOutcome(
            status: SyncStatus.failed,
            operationId: request.idempotencyKey,
            errorCode: resp.errorCode,
            errorMessage: resp.errorMessage,
          );
        case SendClassification.transient:
          return _enqueuePending(request, lastError: resp.errorCode);
      }
    } on NetworkUnavailableException {
      return _enqueuePending(request);
    }
  }

  Future<MutationOutcome> _enqueuePending(
    MutationRequest request, {
    String? lastError,
    Map<String, dynamic>? serverRow,
  }) async {
    await _store.putOperation(
      MutationEnvelope(
        request: request,
        status: SyncStatus.pending,
        createdAt: _clock.now(),
        lastError: lastError,
        serverRow: serverRow,
      ),
    );
    _onQueued?.call();
    // Optimistic, explicitly non-final result (e.g. a fee receipt must not be
    // finalised until confirmed — refinement R1).
    return MutationOutcome(
      status: SyncStatus.pending,
      operationId: request.idempotencyKey,
      data: request.body,
    );
  }
}
