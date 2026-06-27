/// Core enumerations for the Data Reliability Platform (Phase 0).
///
/// These describe *how* a write operation behaves with respect to drafts,
/// offline queueing, retry and conflict handling. Behaviour is driven entirely
/// by the [OperationPolicyRegistry] (refinement R4) — never by per-screen code.
library;

/// How an operation is allowed to be executed by the platform.
enum OperationKind {
  /// Must run online; never queued. Used for auth, payment-gateway redirects
  /// and AI generation where an offline "optimistic" result would be unsafe.
  onlineOnly,

  /// Tried online first; if the network is unavailable (or the server returns a
  /// transient 5xx/429) the write is durably queued in the outbox and replayed
  /// on reconnect with its idempotency key. The caller gets an optimistic result.
  queueable,

  /// Never auto-sent. Persisted locally as a draft and only submitted when the
  /// user explicitly submits (e.g. a multi-step wizard before final submit).
  draftOnly,
}

/// Conflict-handling category (refinement R2 — there is NO global last-write-wins).
enum ConflictCategory {
  /// Drafts, notes, temporary edits and single-owner non-financial data.
  /// On conflict the client write wins (last-write-wins); the overwrite is logged.
  lowRisk,

  /// Money / record-of-truth data: fees, payroll, approvals, published marks,
  /// inventory, finance. On conflict the platform NEVER auto-overwrites — it
  /// parks the operation and requires explicit user resolution.
  highRisk,
}

/// Lifecycle status of a queued mutation in the outbox / sync history.
enum SyncStatus {
  /// In the outbox, waiting to be sent (or waiting for backoff / connectivity).
  pending,

  /// Currently being sent to the server.
  inFlight,

  /// Accepted by the server (or proven already-applied via idempotency replay).
  confirmed,

  /// The server reported a conflict on high-risk data; awaiting user resolution.
  conflict,

  /// Permanently failed (validation / forbidden / not-found / plan-upgrade).
  /// Surfaced to the user; not retried automatically.
  failed,
}
