/// Connectivity abstraction. The real implementation wraps `connectivity_plus`
/// plus a reachability check (connectivity != internet); tests use a fake that
/// can flip online/offline synchronously.
abstract interface class ConnectivityService {
  /// Best-known current state from the OS network interface (necessary, not
  /// sufficient — a live interface can still sit behind a captive portal).
  bool get isOnline;

  /// Emits whenever connectivity changes (true = online).
  Stream<bool> get onStatusChange;

  /// REL-9 — a REAL reachability check (not just the OS interface flag): can the
  /// device actually reach the internet right now? Used to gate the outbox drain
  /// so queued writes are only attempted when there is genuine connectivity
  /// (avoids pointless sends + backoff bumps behind a captive portal). Fails
  /// OPEN when the probe is inconclusive, so it never wrongly blocks a drain.
  Future<bool> isReachable();
}
