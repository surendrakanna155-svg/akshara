/// Injectable clock so backoff/retry timing is deterministic in tests.
abstract interface class ReliabilityClock {
  DateTime now();
}

class SystemReliabilityClock implements ReliabilityClock {
  const SystemReliabilityClock();
  @override
  DateTime now() => DateTime.now();
}
