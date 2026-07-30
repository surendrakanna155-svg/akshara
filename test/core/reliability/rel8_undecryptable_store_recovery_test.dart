import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/reliability/store/reliability_store_opener.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the classifier that decides whether an encrypted-store open failure
/// means "this file cannot be decrypted, rebuild it" or "the platform is
/// broken, do not touch the file".
///
/// The distinction matters in both directions and both are destructive if got
/// wrong:
///   * Too NARROW and an undecryptable database survives, so the app falls back
///     to in-memory on every single launch — permanently and silently costing
///     that device its durability guarantee. This is what shipped: observed on a
///     real device (API 36) as `SQLiteNotADatabaseException: file is not a
///     database (code 26)` after app data was restored without the keystore key
///     that encrypted it.
///   * Too BROAD and a transient platform failure (plugin missing, disk full,
///     keystore unavailable) deletes a perfectly good database full of the
///     user's queued work.
void main() {
  group('undecryptable-store classification', () {
    test('recognises the real on-device failure', () {
      // Verbatim from logcat on the emulator, API 36.
      expect(
        looksUndecryptableStoreError(
          'SQLiteNotADatabaseException: file is not a database (code 26): , '
          'while compiling: SELECT COUNT(*) FROM sqlite_schema;',
        ),
        isTrue,
      );
    });

    test('recognises the wrapped Dart-side exception', () {
      // What the sqflite layer surfaces to Dart for the same condition.
      expect(
        looksUndecryptableStoreError(
          'DatabaseException(open_failed '
          '/data/user/0/com.akshara.erp/databases/akshara_reliability.db)',
        ),
        isTrue,
      );
    });

    test('is case-insensitive', () {
      expect(
        looksUndecryptableStoreError('FILE IS NOT A DATABASE'),
        isTrue,
      );
    });

    test('does NOT match a missing plugin — deleting would be destructive', () {
      expect(
        looksUndecryptableStoreError(
          'MissingPluginException(No implementation found for method read on '
          'channel plugins.it_nomads.com/flutter_secure_storage)',
        ),
        isFalse,
      );
    });

    test('does NOT match disk or permission failures', () {
      expect(looksUndecryptableStoreError('OS Error: No space left on device'),
          isFalse);
      expect(
        looksUndecryptableStoreError(
          'FileSystemException: Cannot open file, path = ... (errno = 13)',
        ),
        isFalse,
      );
    });

    test('does NOT match a keystore failure', () {
      expect(
        looksUndecryptableStoreError(
          'PlatformException(Keystore operation failed)',
        ),
        isFalse,
      );
    });
  });

  group('ReliabilityStoreOpenResult', () {
    test('separates "lost previous work" from "this session is not durable"',
        () {
      // These two facts are independent and must never be conflated: a rebuilt
      // store IS durable going forward, and telling the user their work will be
      // lost when it will now be saved is its own kind of dishonesty.
      final recovered = ReliabilityStoreOpenResult(
        InMemoryReliabilityStore(),
        recovered: true,
        reason: 'rebuilt',
      );
      expect(recovered.recovered, isTrue);
      expect(recovered.degraded, isFalse);

      final degraded = ReliabilityStoreOpenResult(
        InMemoryReliabilityStore(),
        degraded: true,
        reason: 'in-memory',
      );
      expect(degraded.degraded, isTrue);
      expect(degraded.recovered, isFalse);
    });

    test('a clean open claims neither', () {
      final clean = ReliabilityStoreOpenResult(InMemoryReliabilityStore());
      expect(clean.degraded, isFalse);
      expect(clean.recovered, isFalse);
      expect(clean.reason, isNull);
    });
  });
}
