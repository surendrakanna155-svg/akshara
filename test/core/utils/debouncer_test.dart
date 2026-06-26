import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/utils/debouncer.dart';

// PERF-2 (Wave 4): a burst of calls (keystrokes) collapses into a single
// trailing-edge invocation, so a search fetch fires once typing settles rather
// than once per character.
void main() {
  test('collapses a burst into a single trailing call', () {
    fakeAsync((async) {
      final d = Debouncer(delay: const Duration(milliseconds: 300));
      var calls = 0;
      String? last;

      for (final value in ['a', 'ab', 'abc']) {
        d.run(() {
          calls++;
          last = value;
        });
        async.elapse(const Duration(milliseconds: 100)); // faster than the delay
      }
      expect(calls, 0); // nothing fired while typing

      async.elapse(const Duration(milliseconds: 300));
      expect(calls, 1); // exactly one run
      expect(last, 'abc'); // the latest value
      d.dispose();
    });
  });

  test('cancel prevents a pending run', () {
    fakeAsync((async) {
      final d = Debouncer(delay: const Duration(milliseconds: 200));
      var fired = false;
      d.run(() => fired = true);
      expect(d.isActive, isTrue);
      d.cancel();
      async.elapse(const Duration(milliseconds: 500));
      expect(fired, isFalse);
      d.dispose();
    });
  });

  test('separate idle bursts each fire once', () {
    fakeAsync((async) {
      final d = Debouncer(delay: const Duration(milliseconds: 200));
      var calls = 0;
      d.run(() => calls++);
      async.elapse(const Duration(milliseconds: 250));
      d.run(() => calls++);
      async.elapse(const Duration(milliseconds: 250));
      expect(calls, 2);
      d.dispose();
    });
  });
}
