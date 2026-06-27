import 'package:flutter/foundation.dart';

import 'in_memory_reliability_store.dart';
import 'reliability_store.dart';
import 'sqflite_reliability_store.dart';

/// Opens the durable, on-device [ReliabilityStore] used for drafts + the outbox.
///
/// Called once at app start (`main.dart`) and supplied to
/// `reliabilityStoreProvider`. If the encrypted SQLite database cannot be opened
/// for any reason, the platform falls back to an in-memory store so the app
/// still launches — reliability degrades gracefully rather than blocking start.
///
/// Encryption-at-rest (§9) lives inside [SqfliteReliabilityStore.open]; this
/// opener stays unchanged when the cipher is swapped in.
Future<ReliabilityStore> openReliabilityStore() async {
  try {
    return await SqfliteReliabilityStore.open();
  } catch (error, stack) {
    debugPrint('Reliability store: encrypted SQLite open failed, '
        'falling back to in-memory ($error)');
    debugPrintStack(stackTrace: stack, maxFrames: 4);
    return InMemoryReliabilityStore();
  }
}
