import 'package:akshara_erp/core/reliability/sync/backoff.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reliability_fakes.dart';

void main() {
  test('delay grows exponentially with full jitter at the cap', () {
    const b = Backoff(base: Duration(seconds: 1), factor: 2);
    final full = FixedRandom(1.0);
    expect(b.delayFor(1, random: full), const Duration(seconds: 1));
    expect(b.delayFor(2, random: full), const Duration(seconds: 2));
    expect(b.delayFor(3, random: full), const Duration(seconds: 4));
  });

  test('jitter scales the delay between 0 and the exponential value', () {
    const b = Backoff(base: Duration(seconds: 4), factor: 2);
    expect(b.delayFor(1, random: FixedRandom(0.0)), Duration.zero);
    expect(b.delayFor(1, random: FixedRandom(0.5)), const Duration(seconds: 2));
  });

  test('delay is capped at max', () {
    const b = Backoff(
        base: Duration(seconds: 1), factor: 2, max: Duration(seconds: 5));
    expect(b.delayFor(20, random: FixedRandom(1.0)), const Duration(seconds: 5));
  });

  test('attempt < 1 is zero', () {
    expect(const Backoff().delayFor(0), Duration.zero);
  });

  test('shouldRetry respects maxAttempts', () {
    const b = Backoff();
    expect(b.shouldRetry(9, maxAttempts: 10), isTrue);
    expect(b.shouldRetry(10, maxAttempts: 10), isFalse);
  });
}
