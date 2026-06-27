import 'reliability_enums.dart';

/// The result the [MutationGateway] returns to a caller.
///
/// For an online success it carries the server row. For a queued write it is an
/// optimistic [SyncStatus.pending] result (explicitly non-final — e.g. a fee
/// receipt must NOT be finalised until [SyncStatus.confirmed], refinement R1).
class MutationOutcome {
  const MutationOutcome({
    required this.status,
    required this.operationId,
    this.data,
    this.serverRow,
    this.errorCode,
    this.errorMessage,
  });

  final SyncStatus status;

  /// The idempotency key of the operation this outcome corresponds to.
  final String operationId;

  /// The authoritative server row when confirmed; an optimistic projection when
  /// pending. Callers must treat pending data as non-final.
  final Map<String, dynamic>? data;

  /// On conflict, the current server row (for "yours vs theirs" resolution).
  final Map<String, dynamic>? serverRow;

  final String? errorCode;
  final String? errorMessage;

  bool get isConfirmed => status == SyncStatus.confirmed;
  bool get isPending => status == SyncStatus.pending;
  bool get isConflict => status == SyncStatus.conflict;
  bool get isFailed => status == SyncStatus.failed;

  /// True while the result must not be treated as a final, server-backed fact
  /// (drives the "Pending Sync" UI and blocks final-receipt generation, R1).
  bool get isFinal => status == SyncStatus.confirmed;
}
