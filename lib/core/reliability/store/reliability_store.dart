import '../model/cache_record.dart';
import '../model/draft_record.dart';
import '../model/mutation_envelope.dart';

/// Durable local storage for the platform: the outbox (queued writes), drafts
/// (in-progress forms), and the read cache (last-good responses for offline
/// reads).
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

  // ── Read cache ────────────────────────────────────────────────────────────
  /// Persist the last-good response for an idempotent read. Implementations
  /// evict the oldest entries beyond their capacity (LRU-by-write-time) so the
  /// cache cannot grow unbounded.
  Future<void> putCache(CacheRecord record);
  Future<CacheRecord?> getCache(String key);
  Future<void> deleteCache(String key);

  /// Wipe only the read cache (drafts + outbox untouched).
  Future<void> clearCache();

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  /// Wipe all drafts, queued operations, and cached reads (called on logout /
  /// user switch).
  Future<void> clear();
}
