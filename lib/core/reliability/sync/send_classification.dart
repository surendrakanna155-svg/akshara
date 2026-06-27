import 'mutation_executor.dart';

/// How a server response is interpreted by the gateway/engine.
enum SendClassification {
  /// 2xx, or a 409 idempotency replay proving the write was already applied
  /// (exactly-once guarantee even when the original 2xx ack was lost).
  confirmed,

  /// A genuine business conflict (409, not an idempotency replay): the row was
  /// changed by someone else. Carries the current server row.
  conflict,

  /// Permanent client error (4xx other than 409): validation / forbidden /
  /// not-found / plan-upgrade. Not retried.
  failed,

  /// Transient (5xx / 429): worth retrying with backoff.
  transient,
}

/// The error code the backend returns when an idempotent write is replayed
/// because it had already been applied.
const String kIdempotencyConflictCode = 'IDEMPOTENCY_CONFLICT';

SendClassification classifyResponse(ExecutorResponse resp) {
  if (resp.isSuccess) return SendClassification.confirmed;
  if (resp.statusCode == 409) {
    // An idempotency replay means "already applied" → treat as confirmed.
    if (resp.errorCode == kIdempotencyConflictCode) {
      return SendClassification.confirmed;
    }
    return SendClassification.conflict;
  }
  if (resp.isServerError || resp.statusCode == 429) {
    return SendClassification.transient;
  }
  return SendClassification.failed;
}
