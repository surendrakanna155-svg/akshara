import 'dart:math' as math;

/// Exponential backoff with full jitter for retrying transient failures.
///
/// Deterministic when a fixed [random] is injected (tests pass a seeded one).
class Backoff {
  const Backoff({
    this.base = const Duration(seconds: 1),
    this.max = const Duration(minutes: 5),
    this.factor = 2.0,
  });

  final Duration base;
  final Duration max;
  final double factor;

  /// Delay before retry [attempt] (1 = first retry). Applies full jitter in
  /// `[0, exp]` using [random] (defaults to a fresh RNG).
  Duration delayFor(int attempt, {math.Random? random}) {
    if (attempt < 1) return Duration.zero;
    final double expMs =
        base.inMilliseconds * math.pow(factor, attempt - 1).toDouble();
    final double cappedMs = math.min(expMs, max.inMilliseconds.toDouble());
    final math.Random rng = random ?? math.Random();
    final int jitteredMs = (cappedMs * rng.nextDouble()).round();
    return Duration(milliseconds: jitteredMs);
  }

  /// Whether an operation should keep retrying given how many attempts it has
  /// already made. After [maxAttempts] it is parked as permanently failed.
  bool shouldRetry(int attempts, {int maxAttempts = 10}) =>
      attempts < maxAttempts;
}
