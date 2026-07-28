import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show deleteDatabase;

import 'in_memory_reliability_store.dart';
import 'reliability_store.dart';
import 'sqflite_reliability_store.dart';

/// Result of opening the durable store: the store itself plus whether the app
/// had to fall back to a NON-DURABLE in-memory store (REL-8). `degraded == true`
/// means drafts + queued writes will NOT survive a restart this session — a
/// silent data-durability downgrade the app must be able to surface, not hide.
class ReliabilityStoreOpenResult {
  const ReliabilityStoreOpenResult(
    this.store, {
    this.degraded = false,
    this.reason,
    this.recovered = false,
  });

  final ReliabilityStore store;
  final bool degraded;
  final String? reason;

  /// True when an existing database could not be decrypted and was rebuilt
  /// empty. Durability is intact going forward, but anything queued or drafted
  /// on this device beforehand is gone. Deliberately distinct from [degraded]:
  /// one says "this session will not persist", the other says "previous work
  /// was lost but persistence works again".
  final bool recovered;
}

/// Opens the durable, on-device [ReliabilityStore] used for drafts + the outbox.
///
/// Called once at app start (`main.dart`) and supplied to
/// `reliabilityStoreProvider`. If the encrypted SQLite database cannot be opened
/// for any reason, the platform falls back to an in-memory store so the app
/// still launches — reliability degrades gracefully rather than blocking start.
/// REL-8: the fallback is reported back (not just `debugPrint`ed) via
/// [ReliabilityStoreOpenResult.degraded] so the Sync Center / telemetry can make
/// the durability downgrade observable.
///
/// Encryption-at-rest (§9) lives inside [SqfliteReliabilityStore.open]; this
/// opener stays unchanged when the cipher is swapped in.
Future<ReliabilityStoreOpenResult> openReliabilityStore() async {
  try {
    return ReliabilityStoreOpenResult(await SqfliteReliabilityStore.open());
  } catch (error, stack) {
    _log('encrypted SQLite open failed ($error)', stack);

    // The database file exists but the current SQLCipher key does not decrypt
    // it. Seen on a real device (API 36) as:
    //   SQLiteNotADatabaseException: file is not a database (code 26)
    //
    // The key lives in the OS keystore and the database lives in app data, and
    // those two can desynchronise: Android auto-backup restores app data onto a
    // new device, but keystore-held keys are deliberately non-transferable. The
    // previous behaviour fell back to in-memory — and since the undecryptable
    // file is still sitting there on the next launch, it did so on EVERY launch,
    // permanently costing that device its durability guarantee.
    //
    // Nothing in that file is recoverable; the key that could read it is gone.
    // Keeping it buys nothing and costs durability forever, so rebuild it empty
    // and report that separately — losing previously queued work is a different
    // fact from "this session is non-durable", and the user deserves the right
    // one.
    //
    // Guarded on `lastOpenMintedNewKey`: rebuild ONLY when this launch had to
    // mint a fresh key, which is what proves the key that wrote the file is
    // gone. If the key read back fine and the file still will not open, the
    // cause is undiagnosed and deleting would destroy the user's queued work —
    // degrade honestly instead. (Verified on-device: a clean install reads its
    // key back on every launch, so this path stays closed in normal operation.)
    if (_looksUndecryptable(error) &&
        SqfliteReliabilityStore.lastOpenMintedNewKey) {
      try {
        await deleteDatabase(await SqfliteReliabilityStore.databasePath());
        final store = await SqfliteReliabilityStore.open();
        _log('rebuilt an undecryptable store; durability restored', null);
        return ReliabilityStoreOpenResult(
          store,
          recovered: true,
          reason: 'The encrypted store on this device could not be opened and '
              'was rebuilt. Work queued here before now could not be recovered.',
        );
      } catch (retryError, retryStack) {
        _log('rebuild after an undecryptable store also failed ($retryError)',
            retryStack);
      }
    }

    return ReliabilityStoreOpenResult(
      InMemoryReliabilityStore(),
      degraded: true,
      reason: '$error',
    );
  }
}

/// Whether [error] indicates an existing database the current key cannot
/// decrypt, as opposed to a genuine platform failure (plugin missing, no disk,
/// keystore unavailable) where deleting and retrying would be both pointless
/// and destructive.
@visibleForTesting
bool looksUndecryptableStoreError(Object error) => _looksUndecryptable(error);

bool _looksUndecryptable(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('file is not a database') ||
      text.contains('not a database') ||
      text.contains('code 26') ||
      text.contains('open_failed');
}

void _log(String message, StackTrace? stack) {
  if (kReleaseMode) return;
  debugPrint('Reliability store: $message');
  if (stack != null) debugPrintStack(stackTrace: stack, maxFrames: 4);
}
