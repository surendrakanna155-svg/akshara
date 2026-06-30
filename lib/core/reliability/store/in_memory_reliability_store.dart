import '../model/cache_record.dart';
import '../model/draft_record.dart';
import '../model/mutation_envelope.dart';
import '../model/reliability_enums.dart';
import 'reliability_store.dart';

/// In-memory [ReliabilityStore] used by tests and as a safe default before the
/// encrypted SQLite store is wired in. Not durable across restarts.
class InMemoryReliabilityStore implements ReliabilityStore {
  InMemoryReliabilityStore({this.maxCacheEntries = defaultMaxCacheEntries});

  /// Default LRU capacity for the read cache, shared with the SQLite store.
  static const int defaultMaxCacheEntries = 256;

  /// Maximum number of cached read entries retained before the oldest are
  /// evicted (LRU by write time).
  final int maxCacheEntries;

  final Map<String, MutationEnvelope> _ops = <String, MutationEnvelope>{};
  final Map<String, DraftRecord> _drafts = <String, DraftRecord>{};
  final Map<String, CacheRecord> _cache = <String, CacheRecord>{};

  @override
  Future<void> putOperation(MutationEnvelope op) async {
    _ops[op.id] = op;
  }

  @override
  Future<void> deleteOperation(String id) async {
    _ops.remove(id);
  }

  @override
  Future<MutationEnvelope?> getOperation(String id) async => _ops[id];

  @override
  Future<List<MutationEnvelope>> pendingOperations() async {
    final List<MutationEnvelope> pending = _ops.values
        .where((MutationEnvelope o) => o.status == SyncStatus.pending)
        .toList()
      ..sort((MutationEnvelope a, MutationEnvelope b) =>
          a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  @override
  Future<List<MutationEnvelope>> allOperations() async {
    final List<MutationEnvelope> all = _ops.values.toList()
      ..sort((MutationEnvelope a, MutationEnvelope b) =>
          b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<void> putDraft(DraftRecord draft) async {
    _drafts[draft.key] = draft;
  }

  @override
  Future<DraftRecord?> getDraft(String key) async => _drafts[key];

  @override
  Future<void> deleteDraft(String key) async {
    _drafts.remove(key);
  }

  @override
  Future<List<DraftRecord>> draftsForUser(String userId) async {
    final List<DraftRecord> drafts = _drafts.values
        .where((DraftRecord d) => d.userId == userId)
        .toList()
      ..sort((DraftRecord a, DraftRecord b) =>
          b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  @override
  Future<void> putCache(CacheRecord record) async {
    _cache[record.key] = record;
    if (_cache.length > maxCacheEntries) {
      final List<MapEntry<String, CacheRecord>> entries = _cache.entries.toList()
        ..sort((MapEntry<String, CacheRecord> a, MapEntry<String, CacheRecord> b) =>
            a.value.updatedAt.compareTo(b.value.updatedAt));
      for (final MapEntry<String, CacheRecord> e
          in entries.take(_cache.length - maxCacheEntries)) {
        _cache.remove(e.key);
      }
    }
  }

  @override
  Future<CacheRecord?> getCache(String key) async => _cache[key];

  @override
  Future<void> deleteCache(String key) async {
    _cache.remove(key);
  }

  @override
  Future<void> clearCache() async {
    _cache.clear();
  }

  @override
  Future<void> clear() async {
    _ops.clear();
    _drafts.clear();
    _cache.clear();
  }
}
