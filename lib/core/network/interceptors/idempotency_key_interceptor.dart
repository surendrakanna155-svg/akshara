import 'package:dio/dio.dart';

import '../../reliability/reliability_ids.dart';

/// REL-1 (P1-CODE-1): mints an `Idempotency-Key` for **every** mutating request
/// that does not already carry one.
///
/// The backend runs universal store-and-replay idempotency at its dispatch choke
/// point (`dispatchWithIdempotency`) — any mutating route carrying the header
/// replays exactly once, and is inert without it. Before this interceptor only
/// the ~6 `ReliableWriter` paths minted a key, so the other ~148 direct-Dio
/// mutations were unprotected: a write delivered twice (a 401 refresh→replay, a
/// resend) could duplicate the row (double fee / double leave). Minting a key
/// here for all POST/PUT/PATCH/DELETE requests closes that gap end-to-end.
///
/// The key is set on the request options once, so an in-Dio replay (the auth
/// interceptor re-sends the same options) reuses the same key and is deduped.
/// `ReliableWriter` writes already carry their own stable key from the outbox —
/// this interceptor never overwrites an existing one. Place it BEFORE the auth
/// interceptor so a refresh→replay carries the key.
class IdempotencyKeyInterceptor extends Interceptor {
  static const String headerName = 'Idempotency-Key';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (_isMutating(options.method) && !_hasKey(options.headers)) {
      options.headers[headerName] = newOperationId();
    }
    handler.next(options);
  }

  bool _isMutating(String method) {
    switch (method.toUpperCase()) {
      case 'POST':
      case 'PUT':
      case 'PATCH':
      case 'DELETE':
        return true;
      default:
        return false;
    }
  }

  bool _hasKey(Map<String, dynamic> headers) {
    for (final key in headers.keys) {
      if (key.toLowerCase() == 'idempotency-key') return true;
    }
    return false;
  }
}
