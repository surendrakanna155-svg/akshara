import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../model/draft_record.dart';
import '../model/mutation_envelope.dart';
import '../model/reliability_enums.dart';
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
  SqfliteReliabilityStore(this._db);

  final Database _db;

  static const String _opsTable = 'reliability_outbox';
  static const String _draftsTable = 'reliability_drafts';

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
      version: 1,
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
      },
    );
    return SqfliteReliabilityStore(db);
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
  Future<void> clear() async {
    await _db.delete(_opsTable);
    await _db.delete(_draftsTable);
  }

  MutationEnvelope _decodeOp(Map<String, Object?> row) =>
      MutationEnvelope.fromJson(
          jsonDecode(row['json'] as String) as Map<String, dynamic>);

  DraftRecord _decodeDraft(Map<String, Object?> row) => DraftRecord.fromJson(
      jsonDecode(row['json'] as String) as Map<String, dynamic>);
}
