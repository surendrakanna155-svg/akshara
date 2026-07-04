import 'dart:async';

import 'package:flutter/foundation.dart';

import '../connectivity/connectivity_service.dart';
import '../store/reliability_store.dart';
import '../sync/sync_engine.dart';
import 'sync_summary.dart';

/// Backs the Sync Center (R3): exposes a live [SyncSummary] and the user
/// actions — manual retry and conflict resolution.
class SyncCenterController extends ChangeNotifier {
  SyncCenterController({
    required ReliabilityStore store,
    required ConnectivityService connectivity,
    required SyncEngine engine,
    bool durabilityDegraded = false,
  })  : _store = store,
        _connectivity = connectivity,
        _engine = engine,
        _durabilityDegraded = durabilityDegraded {
    _connSub = _connectivity.onStatusChange.listen((_) => refresh());
    // Initial load.
    unawaited(refresh());
  }

  final ReliabilityStore _store;
  final ConnectivityService _connectivity;
  final SyncEngine _engine;
  final bool _durabilityDegraded;
  StreamSubscription<bool>? _connSub;

  SyncSummary _summary = const SyncSummary();
  SyncSummary get summary => _summary;

  Future<void> refresh() async {
    final summary = SyncSummary.fromOperations(
      await _store.allOperations(),
      online: _connectivity.isOnline,
      durabilityDegraded: _durabilityDegraded,
    );
    _summary = summary;
    notifyListeners();
  }

  /// "Retry now" — re-queue failed ops and drain immediately.
  Future<void> retryAll() async {
    await _engine.retryAllNow();
    await refresh();
  }

  /// Resolve a parked high-risk conflict: keep the user's copy (re-apply with
  /// the server precondition) or accept the server copy (drop the op).
  Future<void> resolveConflict(String operationId,
      {required bool keepClient}) async {
    await _engine.resolveConflict(operationId, keepClient: keepClient);
    await _engine.flush();
    await refresh();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}
