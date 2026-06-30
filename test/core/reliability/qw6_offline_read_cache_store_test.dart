import 'package:akshara_erp/core/reliability/model/cache_record.dart';
import 'package:akshara_erp/core/reliability/model/draft_record.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW6 · QA-X-004 — read-cache store contract.
///
/// Phase 0 gave the platform a durable *write* outbox + drafts but no read
/// cache, so the app was unusable offline (every read fetched live). This row
/// BUILDS the read-side counterpart: the [ReliabilityStore] now persists the
/// last-good response body for an idempotent read, evicts oldest-first beyond a
/// capacity, and is wiped alongside drafts/outbox on logout.
void main() {
  CacheRecord record(String key, {DateTime? at}) => CacheRecord(
        key: key,
        scope: 't1|s1|u1',
        json: <String, dynamic>{'value': key},
        updatedAt: at ?? DateTime(2026, 6, 30, 9),
      );

  group('read cache CRUD (QA-X-004)', () {
    test('put then get returns the cached body', () async {
      final store = InMemoryReliabilityStore();
      await store.putCache(record('GET /a'));

      final hit = await store.getCache('GET /a');
      expect(hit, isNotNull);
      expect(hit!.json['value'], 'GET /a');
    });

    test('get for an unknown key returns null', () async {
      final store = InMemoryReliabilityStore();
      expect(await store.getCache('GET /missing'), isNull);
    });

    test('put replaces an existing entry for the same key', () async {
      final store = InMemoryReliabilityStore();
      await store.putCache(record('GET /a', at: DateTime(2026, 6, 30, 9)));
      await store.putCache(CacheRecord(
        key: 'GET /a',
        json: const <String, dynamic>{'value': 'fresh'},
        updatedAt: DateTime(2026, 6, 30, 10),
      ));

      final hit = await store.getCache('GET /a');
      expect(hit!.json['value'], 'fresh');
    });

    test('deleteCache removes a single entry', () async {
      final store = InMemoryReliabilityStore();
      await store.putCache(record('GET /a'));
      await store.deleteCache('GET /a');
      expect(await store.getCache('GET /a'), isNull);
    });
  });

  group('eviction + lifecycle (QA-X-004)', () {
    test('evicts oldest entries beyond capacity (LRU by write time)', () async {
      final store = InMemoryReliabilityStore(maxCacheEntries: 3);
      // Insert 4 entries with increasing timestamps; the oldest must be evicted.
      for (int i = 0; i < 4; i++) {
        await store.putCache(record('GET /$i', at: DateTime(2026, 6, 30, 9, i)));
      }
      expect(await store.getCache('GET /0'), isNull,
          reason: 'oldest entry evicted once capacity is exceeded');
      expect(await store.getCache('GET /1'), isNotNull);
      expect(await store.getCache('GET /3'), isNotNull);
    });

    test('clearCache wipes only the cache, not drafts/outbox', () async {
      final store = InMemoryReliabilityStore();
      await store.putCache(record('GET /a'));
      await store.putDraft(DraftRecord(
        key: 'd1',
        userId: 'u1',
        json: const <String, dynamic>{},
        updatedAt: DateTime(2026, 6, 30),
      ));

      await store.clearCache();

      expect(await store.getCache('GET /a'), isNull);
      expect(await store.getDraft('d1'), isNotNull,
          reason: 'clearCache must not touch drafts');
    });

    test('clear() (logout) wipes the cache along with drafts', () async {
      final store = InMemoryReliabilityStore();
      await store.putCache(record('GET /a'));
      await store.putDraft(DraftRecord(
        key: 'd1',
        userId: 'u1',
        json: const <String, dynamic>{},
        updatedAt: DateTime(2026, 6, 30),
      ));

      await store.clear();

      expect(await store.getCache('GET /a'), isNull);
      expect(await store.getDraft('d1'), isNull,
          reason: 'logout wipe must clear cache + drafts together');
    });
  });

  group('CacheRecord serialization', () {
    test('round-trips through json', () {
      final r = record('GET /a');
      final decoded = CacheRecord.fromJson(r.toJson());
      expect(decoded.key, r.key);
      expect(decoded.scope, r.scope);
      expect(decoded.json['value'], 'GET /a');
      expect(decoded.updatedAt, r.updatedAt);
    });
  });
}
