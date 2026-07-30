// Living Dashboard — snooze math and lifecycle wire contract.
//
// These are pure/clock-injected on purpose: the presets must be provable without
// waiting for a wall clock, and the IST day math must be provable from a device
// in any timezone.

import 'package:flutter_test/flutter_test.dart';
import 'package:akshara_erp/features/adaptive_ai/adaptive_lifecycle.dart';

void main() {
  group('resolveSnoozeUntil', () {
    test('30 minutes is a plain offset from now', () {
      final now = DateTime.utc(2026, 7, 10, 6, 0);
      final until = resolveSnoozeUntil(AdaptiveSnoozeOption.thirtyMinutes, now);
      expect(until, DateTime.utc(2026, 7, 10, 6, 30));
    });

    test('tomorrow morning is 08:00 IST the next school day', () {
      // 11:30 IST on 2026-07-10 → 08:00 IST on 2026-07-11 → 02:30 UTC.
      final now = DateTime.utc(2026, 7, 10, 6, 0);
      final until = resolveSnoozeUntil(AdaptiveSnoozeOption.tomorrowMorning, now);
      expect(until, DateTime.utc(2026, 7, 11, 2, 30));
    });

    test('tomorrow morning uses the IST day, not the UTC day', () {
      // 2026-07-10T20:00Z is already 01:30 IST on 2026-07-11, so "tomorrow"
      // must mean the 12th — not the 11th a UTC reading would give.
      final now = DateTime.utc(2026, 7, 10, 20, 0);
      final until = resolveSnoozeUntil(AdaptiveSnoozeOption.tomorrowMorning, now);
      expect(until, DateTime.utc(2026, 7, 12, 2, 30));
    });

    test('hide for today ends at IST midnight', () {
      // End of the 2026-07-10 IST day = 2026-07-10T18:30Z.
      final now = DateTime.utc(2026, 7, 10, 6, 0);
      final until = resolveSnoozeUntil(AdaptiveSnoozeOption.restOfToday, now);
      expect(until, DateTime.utc(2026, 7, 10, 18, 30));
    });

    test('every preset resolves to a future instant', () {
      final now = DateTime.utc(2026, 7, 10, 6, 0);
      for (final option in AdaptiveSnoozeOption.values) {
        expect(
          resolveSnoozeUntil(option, now).isAfter(now),
          isTrue,
          reason: '${option.name} must be in the future or it buries the item',
        );
      }
    });

    test('a device in another timezone still snoozes to the school day', () {
      // Same instant, expressed in a non-UTC zone.
      final utc = DateTime.utc(2026, 7, 10, 6, 0);
      final shifted = utc.toLocal();
      expect(
        resolveSnoozeUntil(AdaptiveSnoozeOption.tomorrowMorning, shifted),
        resolveSnoozeUntil(AdaptiveSnoozeOption.tomorrowMorning, utc),
      );
    });
  });

  group('wire contract', () {
    test('states match the vocabulary the migration CHECK enforces', () {
      expect(AdaptiveLifecycleAction.acknowledge.wireState, 'acknowledged');
      expect(AdaptiveLifecycleAction.snooze.wireState, 'snoozed');
      expect(AdaptiveLifecycleAction.complete.wireState, 'completed');
    });

    test('a snooze serializes its end as UTC ISO-8601', () {
      final write = AdaptiveLifecycleWrite(
        action: AdaptiveLifecycleAction.snooze,
        snoozedUntil: DateTime.utc(2026, 7, 11, 2, 30),
        scoreAtAction: 62,
        dueAtAction: 3,
      );
      expect(write.toJson(), {
        'state': 'snoozed',
        'snoozedUntil': '2026-07-11T02:30:00.000Z',
        'scoreAtAction': 62,
        'dueAtAction': 3,
      });
    });

    test('omitted watermarks are absent, not null — the server reads absent as "no baseline"', () {
      final write = AdaptiveLifecycleWrite(action: AdaptiveLifecycleAction.acknowledge);
      expect(write.toJson(), {'state': 'acknowledged'});
    });

    test('a snooze without an end is rejected before it can reach the server', () {
      expect(
        () => AdaptiveLifecycleWrite(action: AdaptiveLifecycleAction.snooze),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
