import 'package:flutter/foundation.dart';

import 'in_memory_reliability_store.dart';
import 'reliability_store.dart';
import 'sqflite_reliability_store.dart';

/// Result of opening the durable store: the store itself plus whether the app
/// had to fall back to a NON-DURABLE in-memory store (REL-8). `degraded == true`
/// means drafts + queued writes will NOT survive a restart this session — a
/// silent data-durability downgrade the app must be able to surface, not hide.
class ReliabilityStoreOpenResult {
  const ReliabilityStoreOpenResult(this.store, {this.degraded = false, this.reason});

  final ReliabilityStore store;
  final bool degraded;
  final String? reason;
}

/// Opens the durable, on-device [ReliabilityStore] used for drafts + the outbox.
///
/// Called once at app start (`main.dart`) and supplied to
/// `reliabilityStoreProvider`. If the encrypted SQLite database cannot be opened
/// for any reason, the platform falls back to an in-memory store so the app
/// still launches — reliability degrades gracefully rather than blocking start.
/// REL-8: the fallback is now reported back (not just `debugPrint`ed) via
/// [ReliabilityStoreOpenResult.degraded] so the Sync Center / telemetry can make
/// the durability downgrade observable.
///
/// Encryption-at-rest (§9) lives inside [SqfliteReliabilityStore.open]; this
/// opener stays unchanged when the cipher is swapped in.
Future<ReliabilityStoreOpenResult> openReliabilityStore() async {
  try {
    return ReliabilityStoreOpenResult(await SqfliteReliabilityStore.open());
  } catch (error, stack) {
    if (!kReleaseMode) {
      debugPrint('Reliability store: encrypted SQLite open failed, '
          'falling back to in-memory ($error)');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
    }
    return ReliabilityStoreOpenResult(
      InMemoryReliabilityStore(),
      degraded: true,
      reason: '$error',
    );
  }
}
