import 'dart:async';
import 'dart:math' as math;

import 'package:akshara_erp/core/reliability/connectivity/connectivity_service.dart';
import 'package:akshara_erp/core/reliability/model/mutation_request.dart';
import 'package:akshara_erp/core/reliability/sync/mutation_executor.dart';
import 'package:akshara_erp/core/reliability/sync/reliability_clock.dart';

/// Scriptable executor: a responder decides the response per call (and may throw
/// [NetworkUnavailableException]). Records every request for assertions.
class FakeExecutor implements MutationExecutor {
  FakeExecutor(this.responder);

  /// (request, zero-based call index) → response. May throw.
  final FutureOr<ExecutorResponse> Function(MutationRequest req, int callIndex)
      responder;

  final List<MutationRequest> sent = <MutationRequest>[];
  int get callCount => sent.length;

  @override
  Future<ExecutorResponse> send(MutationRequest request) async {
    final int index = sent.length;
    sent.add(request);
    return await responder(request, index);
  }
}

ExecutorResponse ok([Map<String, dynamic>? data]) =>
    ExecutorResponse(statusCode: 200, data: data ?? <String, dynamic>{'ok': true});

ExecutorResponse serverError() =>
    const ExecutorResponse(statusCode: 503, errorCode: 'SERVER_ERROR');

ExecutorResponse validationError() => const ExecutorResponse(
    statusCode: 422, errorCode: 'VALIDATION_ERROR', errorMessage: 'bad');

ExecutorResponse conflict(Map<String, dynamic> serverRow) =>
    ExecutorResponse(statusCode: 409, data: serverRow, errorCode: 'CONFLICT');

ExecutorResponse idempotencyReplay([Map<String, dynamic>? data]) =>
    ExecutorResponse(
        statusCode: 409, data: data, errorCode: 'IDEMPOTENCY_CONFLICT');

class FakeConnectivity implements ConnectivityService {
  FakeConnectivity({bool online = true}) : _online = online;
  bool _online;
  // When set, overrides the reachability probe result; otherwise reachability
  // mirrors [isOnline] (so existing tests behave exactly as before).
  bool? _reachableOverride;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  @override
  Future<bool> isReachable() async => _reachableOverride ?? _online;

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  /// REL-9 — simulate "OS says online but the internet is unreachable"
  /// (captive portal): [isOnline] stays true while [isReachable] returns false.
  void setReachable(bool? value) => _reachableOverride = value;

  Future<void> dispose() => _controller.close();
}

class FixedClock implements ReliabilityClock {
  FixedClock(this._now);
  DateTime _now;
  @override
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
  void setNow(DateTime t) => _now = t;
}

/// math.Random that returns a fixed nextDouble, making jittered backoff
/// deterministic in tests.
class FixedRandom implements math.Random {
  FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => (value * max).floor().clamp(0, max - 1);
  @override
  bool nextBool() => value >= 0.5;
}

MutationRequest req(
  String type, {
  String? id,
  String method = 'POST',
  String path = '/x',
  Map<String, dynamic> body = const <String, dynamic>{},
  String? entityRef,
}) {
  return MutationRequest(
    type: type,
    method: method,
    path: path,
    idempotencyKey: id ?? 'op-$type',
    body: body,
    entityRef: entityRef,
  );
}
