/// Lightweight inference telemetry (FV-PLAT-10).
class AiInferenceTelemetry {
  final List<AiInferenceEvent> _events = [];

  List<AiInferenceEvent> get events => List.unmodifiable(_events);

  void record(AiInferenceEvent event) {
    _events.add(event);
    if (_events.length > 500) {
      _events.removeRange(0, _events.length - 500);
    }
  }

  void clear() => _events.clear();
}

class AiInferenceEvent {
  const AiInferenceEvent({
    required this.taskType,
    required this.provider,
    required this.success,
    required this.fromCache,
    required this.usedFallback,
    this.latencyMs,
    this.errorCode,
  });

  final String taskType;
  final String provider;
  final bool success;
  final bool fromCache;
  final bool usedFallback;
  final int? latencyMs;
  final String? errorCode;
}
