import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_service.dart';

/// Production [ConnectivityService] backed by `connectivity_plus`.
///
/// Network *interface* availability is a necessary (not sufficient) signal for
/// reachability; the sync engine treats "online" as "worth attempting" and
/// relies on the server response for the source of truth, so interface-level
/// detection is safe here.
class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final Connectivity _connectivity;
  bool _isOnline = true;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> _init() async {
    try {
      _isOnline = _online(await _connectivity.checkConnectivity());
    } catch (_) {
      _isOnline = true; // fail open: don't block writes if detection fails
    }
    // Subscribing touches a platform channel (EventChannel). In a binding-less
    // environment (pure unit tests with no `TestWidgetsFlutterBinding`) the
    // subscription throws an *asynchronous* "Binding not initialized" error that
    // a plain try/catch can't capture. `runZonedGuarded` swallows both the sync
    // and the async failure so the platform is safe to construct anywhere; when
    // connectivity can't be observed we simply stay optimistically "online".
    runZonedGuarded(() {
      _sub = _connectivity.onConnectivityChanged.listen(
        (results) {
          final bool next = _online(results);
          if (next != _isOnline) {
            _isOnline = next;
            _controller.add(next);
          }
        },
        onError: (_) {},
      );
    }, (_, __) {});
  }

  bool _online(List<ConnectivityResult> results) =>
      results.any((ConnectivityResult r) => r != ConnectivityResult.none);

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> dispose() async {
    // Cancelling the platform subscription can also touch the binary messenger
    // and fail asynchronously in a binding-less test; run it in a guarded zone
    // (matching the subscribe) so disposing the service never throws.
    final StreamSubscription<List<ConnectivityResult>>? sub = _sub;
    _sub = null;
    runZonedGuarded(() {
      sub?.cancel();
    }, (_, __) {});
    try {
      await _controller.close();
    } catch (_) {}
  }
}
