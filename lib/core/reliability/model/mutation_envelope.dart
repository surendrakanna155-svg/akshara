import 'mutation_request.dart';
import 'reliability_enums.dart';

/// The durable unit of work stored in the outbox.
///
/// Wraps a [MutationRequest] with its sync lifecycle state so the [SyncEngine]
/// can drain, retry and reconcile it across app restarts.
class MutationEnvelope {
  const MutationEnvelope({
    required this.request,
    required this.status,
    required this.createdAt,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
    this.serverRow,
  });

  factory MutationEnvelope.create(
    MutationRequest request, {
    required DateTime now,
  }) {
    return MutationEnvelope(
      request: request,
      status: SyncStatus.pending,
      createdAt: now,
    );
  }

  final MutationRequest request;
  final SyncStatus status;
  final DateTime createdAt;
  final int attempts;

  /// Earliest time the engine may retry this op (set by the backoff policy).
  final DateTime? nextAttemptAt;

  /// Last error code/message for diagnostics + the Sync Center history.
  final String? lastError;

  /// On a high-risk conflict, the current server row to show "yours vs theirs".
  final Map<String, dynamic>? serverRow;

  /// Stable id for this operation (its idempotency key).
  String get id => request.idempotencyKey;

  MutationEnvelope copyWith({
    MutationRequest? request,
    SyncStatus? status,
    DateTime? createdAt,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
    String? lastError,
    bool clearLastError = false,
    Map<String, dynamic>? serverRow,
    bool clearServerRow = false,
  }) {
    return MutationEnvelope(
      request: request ?? this.request,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      nextAttemptAt:
          clearNextAttemptAt ? null : (nextAttemptAt ?? this.nextAttemptAt),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      serverRow: clearServerRow ? null : (serverRow ?? this.serverRow),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'request': request.toJson(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        'nextAttemptAt': nextAttemptAt?.toIso8601String(),
        'lastError': lastError,
        'serverRow': serverRow,
      };

  factory MutationEnvelope.fromJson(Map<String, dynamic> json) {
    return MutationEnvelope(
      request:
          MutationRequest.fromJson((json['request'] as Map).cast<String, dynamic>()),
      status: SyncStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAt: json['nextAttemptAt'] == null
          ? null
          : DateTime.parse(json['nextAttemptAt'] as String),
      lastError: json['lastError'] as String?,
      serverRow: (json['serverRow'] as Map?)?.cast<String, dynamic>(),
    );
  }
}
