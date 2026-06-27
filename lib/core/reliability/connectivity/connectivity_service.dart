/// Connectivity abstraction. The real implementation wraps `connectivity_plus`
/// plus a reachability check (connectivity != internet); tests use a fake that
/// can flip online/offline synchronously.
abstract interface class ConnectivityService {
  /// Best-known current state.
  bool get isOnline;

  /// Emits whenever connectivity changes (true = online).
  Stream<bool> get onStatusChange;
}
