import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../model/cache_record.dart';
import '../model/draft_record.dart';
import '../model/mutation_envelope.dart';
import '../model/reliability_enums.dart';
import 'in_memory_reliability_store.dart';
import 'reliability_store.dart';

/// Durable [ReliabilityStore] backed by SQLite (sqflite). The outbox and drafts
/// survive app restart / kill — the core of "never lose work".
///
/// ENCRYPTION-AT-REST (§9): drafts/outbox can hold PII (marks, fees, names), so
/// the database is opened with SQLCipher using a 256-bit key held in
/// `flutter_secure_storage` (the OS keystore / keychain). The key is generated
/// once on first launch and never leaves secure storage; the table schema and
/// all logic below are identical to plain sqflite.
class SqfliteReliabilityStore implements ReliabilityStore {
  SqfliteReliabilityStore(
    this._db, {
    this.maxCacheEntries = InMemoryReliabilityStore.defaultMaxCacheEntries,
  });

  final Database _db;

  /// LRU capacity for the read-cache table (oldest evicted on insert).
  final int maxCacheEntries;

  static const String _opsTable = 'reliability_outbox';
  static const String _draftsTable = 'reliability_drafts';
  static const String _cacheTable = 'reliability_read_cache';

  /// Secure-storage key name holding the SQLCipher passphrase.
  static const String _cipherKeyName = 'reliability_db_cipher_key_v1';

  /// Generate-once / read-back a 256-bit SQLCipher passphrase from the OS secure
  /// storage. The key never leaves the keystore and is wiped with the app.
  static Future<String> _obtainCipherKey(FlutterSecureStorage storage) async {
    final String? existing = await storage.read(key: _cipherKeyName);
    if (existing != null && existing.isNotEmpty) return existing;
    final Random rng = Random.secure();
    final List<int> bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final String key = base64UrlEncode(bytes);
    await storage.write(key: _cipherKeyName, value: key);
    return key;
  }

  static Future<SqfliteReliabilityStore> open({
    FlutterSecureStorage? secureStorage,
  }) async {
    final FlutterSecureStorage storage =
        secureStorage ?? const FlutterSecureStorage();
    final String password = await _obtainCipherKey(storage);
    final String dir = await getDatabasesPath();
    final String path = p.join(dir, 'akshara_reliability.db');
    final Database db = await openDatabase(
      path,
      password: password,
      version: 2,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_opsTable (
            id TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_outbox_status ON $_opsTable(status, created_at)');
        await db.execute('''
          CREATE TABLE $_draftsTable (
            key TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            school_id TEXT,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_drafts_user ON $_draftsTable(user_id, updated_at)');
        await _createCacheTable(db);
      },
      // v1 → v2 (QA-X-004): add the read-cache table to existing installs so the
      // upgrade never drops queued writes / drafts already on the device.
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await _createCacheTable(db);
        }
      },
    );
    return SqfliteReliabilityStore(db);
  }

  /// Read-cache schema, shared by fresh creates and the v1→v2 migration.
  static Future<void> _createCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_cacheTable (
        key TEXT PRIMARY KEY,
        scope TEXT,
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_cache_updated ON $_cacheTable(updated_at)');
  }

  @override
  Future<void> putOperation(MutationEnvelope op) async {
    await _db.insert(
      _opsTable,
      <String, Object?>{
        'id': op.id,
        'json': jsonEncode(op.toJson()),
        'status': op.status.name,
        'created_at': op.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteOperation(String id) async {
    await _db.delete(_opsTable, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  @override
  Future<MutationEnvelope?> getOperation(String id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _opsTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeOp(rows.first);
  }

  @override
  Future<List<MutationEnvelope>> pendingOperations() async {
    final List<Map<String, Object?>> rows = await _db.query(
      _opsTable,
      where: 'status = ?',
      whereArgs: <Object?>[SyncStatus.pending.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(_decodeOp).toList();
  }

  @override
  Future<List<MutationEnvelope>> allOperations() async {
    final List<Map<String, Object?>> rows =
        await _db.query(_opsTable, orderBy: 'created_at DESC');
    return rows.map(_decodeOp).toList();
  }

  @override
  Future<void> putDraft(DraftRecord draft) async {
    await _db.insert(
      _draftsTable,
      <String, Object?>{
        'key': draft.key,
        'user_id': draft.userId,
        'school_id': draft.schoolId,
        'json': jsonEncode(draft.toJson()),
        'updated_at': draft.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<DraftRecord?> getDraft(String key) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _draftsTable,
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeDraft(rows.first);
  }

  @override
  Future<void> deleteDraft(String key) async {
    await _db.delete(_draftsTable, where: 'key = ?', whereArgs: <Object?>[key]);
  }

  @override
  Future<List<DraftRecord>> draftsForUser(String userId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _draftsTable,
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_decodeDraft).toList();
  }

  @override
  Future<void> putCache(CacheRecord record) async {
    await _db.insert(
      _cacheTable,
      <String, Object?>{
        'key': record.key,
        'scope': record.scope,
        'json': jsonEncode(record.json),
        'updated_at': record.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // LRU eviction: keep only the newest [maxCacheEntries] rows.
    await _db.rawDelete(
      'DELETE FROM $_cacheTable WHERE key NOT IN '
      '(SELECT key FROM $_cacheTable ORDER BY updated_at DESC LIMIT ?)',
      <Object?>[maxCacheEntries],
    );
  }

  @override
  Future<CacheRecord?> getCache(String key) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _cacheTable,
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeCache(rows.first);
  }

  @override
  Future<void> deleteCache(String key) async {
    await _db.delete(_cacheTable, where: 'key = ?', whereArgs: <Object?>[key]);
  }

  @override
  Future<void> clearCache() async {
    await _db.delete(_cacheTable);
  }

  @override
  Future<void> clear() async {
    await _db.delete(_opsTable);
    await _db.delete(_draftsTable);
    await _db.delete(_cacheTable);
  }

  CacheRecord _decodeCache(Map<String, Object?> row) => CacheRecord(
        key: row['key'] as String,
        scope: row['scope'] as String?,
        json: jsonDecode(row['json'] as String) as Map<String, dynamic>,
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );

  MutationEnvelope _decodeOp(Map<String, Object?> row) =>
      MutationEnvelope.fromJson(
          jsonDecode(row['json'] as String) as Map<String, dynamic>);

  DraftRecord _decodeDraft(Map<String, Object?> row) => DraftRecord.fromJson(
      jsonDecode(row['json'] as String) as Map<String, dynamic>);
}
