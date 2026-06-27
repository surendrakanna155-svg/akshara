import '../model/draft_record.dart';
import '../model/mutation_envelope.dart';

/// Durable local storage for the platform: the outbox (queued writes) and
/// drafts (in-progress forms).
///
/// The interface keeps the sync engine storage-agnostic and fully unit-testable
/// ([InMemoryReliabilityStore]); the production implementation is backed by an
/// encrypted SQLite database ([SqfliteReliabilityStore]).
abstract interface class ReliabilityStore {
  // ── Outbox ────────────────────────────────────────────────────────────────
  Future<void> putOperation(MutationEnvelope op);
  Future<void> deleteOperation(String id);
  Future<MutationEnvelope?> getOperation(String id);

  /// Operations still needing work (pending), oldest first.
  Future<List<MutationEnvelope>> pendingOperations();

  /// Everything currently retained, newest first — drives the sync history.
  Future<List<MutationEnvelope>> allOperations();

  // ── Drafts ──────────────────────────────────────────────────────────────--
  Future<void> putDraft(DraftRecord draft);
  Future<DraftRecord?> getDraft(String key);
  Future<void> deleteDraft(String key);
  Future<List<DraftRecord>> draftsForUser(String userId);

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  /// Wipe all drafts and queued operations (called on logout / user switch).
  Future<void> clear();
}
