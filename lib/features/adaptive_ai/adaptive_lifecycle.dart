// Living Dashboard — client-side lifecycle vocabulary and snooze math.
//
// Pure and clock-injected: every function takes `now` so the presets are
// testable without waiting for a wall clock. Mirrors the backend resolver in
// `supabase/functions/_shared/intelligence/priority/item_lifecycle.ts` — the
// wire values here MUST match the state vocabulary that migration
// 20260920000400 enforces with a CHECK constraint.
//
// Day math is computed on the IST wall clock, not the device's local zone, for
// the same reason `feed_dates.ts` does it server-side: NIKSHA is India-first, so
// "tomorrow morning" must mean the school's tomorrow. A device left on another
// timezone would otherwise snooze an item to the wrong school day.

import 'package:flutter/foundation.dart';

/// India Standard Time offset. Matches `IST_OFFSET_MS` in feed_dates.ts.
const Duration kIstOffset = Duration(hours: 5, minutes: 30);

/// The hour (IST) that "tomorrow morning" resolves to — before first period, so
/// a teacher sees the item when they start the day rather than mid-lesson.
const int kTomorrowMorningHourIst = 8;

/// What the user can do to an item on the dashboard. These map to the backend's
/// stored lifecycle states; the states the client never writes (`new`, `urgent`,
/// `expired`, `escalated`) are system-derived and deliberately absent here.
enum AdaptiveLifecycleAction {
  /// "Seen it" — day-scoped, returns tomorrow if still true.
  acknowledge,

  /// "Not now" — returns when the window closes.
  snooze,

  /// "Done" — terminal; never resurfaces on its own.
  complete,
}

extension AdaptiveLifecycleActionWire on AdaptiveLifecycleAction {
  /// The `lifecycle.state` value the feedback route expects.
  String get wireState => switch (this) {
        AdaptiveLifecycleAction.acknowledge => 'acknowledged',
        AdaptiveLifecycleAction.snooze => 'snoozed',
        AdaptiveLifecycleAction.complete => 'completed',
      };
}

/// The snooze presets the mission names: "remind me in 30 minutes", "remind me
/// tomorrow morning", "hide for today".
enum AdaptiveSnoozeOption { thirtyMinutes, tomorrowMorning, restOfToday }

extension AdaptiveSnoozeOptionLabel on AdaptiveSnoozeOption {
  String get label => switch (this) {
        AdaptiveSnoozeOption.thirtyMinutes => 'In 30 minutes',
        AdaptiveSnoozeOption.tomorrowMorning => 'Tomorrow morning',
        AdaptiveSnoozeOption.restOfToday => 'Hide for today',
      };
}

/// Resolve a preset to the absolute instant the item should return.
///
/// Pure. `now` may be in any zone — it is converted to UTC first, so the result
/// is a correct instant regardless of the device's timezone setting.
DateTime resolveSnoozeUntil(AdaptiveSnoozeOption option, DateTime now) {
  final nowUtc = now.toUtc();
  switch (option) {
    case AdaptiveSnoozeOption.thirtyMinutes:
      return nowUtc.add(const Duration(minutes: 30));

    case AdaptiveSnoozeOption.tomorrowMorning:
      final ist = nowUtc.add(kIstOffset);
      // 08:00 IST on the NEXT IST calendar day, converted back to a UTC instant.
      final target = DateTime.utc(ist.year, ist.month, ist.day)
          .add(const Duration(days: 1))
          .add(const Duration(hours: kTomorrowMorningHourIst));
      return target.subtract(kIstOffset);

    case AdaptiveSnoozeOption.restOfToday:
      final ist = nowUtc.add(kIstOffset);
      // Midnight at the end of the current IST day.
      final target =
          DateTime.utc(ist.year, ist.month, ist.day).add(const Duration(days: 1));
      return target.subtract(kIstOffset);
  }
}

/// A lifecycle write, as the client sends it alongside (or instead of) a
/// learning signal.
///
/// `scoreAtAction` and `dueAtAction` are the watermarks that make "bring it back
/// when it gets worse" decidable server-side. Sending them is not optional in
/// spirit: omitting `scoreAtAction` permanently disables escalation for that
/// row, so the item could only ever return on the day boundary.
@immutable
class AdaptiveLifecycleWrite {
  const AdaptiveLifecycleWrite({
    required this.action,
    this.snoozedUntil,
    this.scoreAtAction,
    this.dueAtAction,
  }) : assert(
          action != AdaptiveLifecycleAction.snooze || snoozedUntil != null,
          'a snooze without an end is a permanent bury — the backend rejects it (422)',
        );

  final AdaptiveLifecycleAction action;
  final DateTime? snoozedUntil;
  final int? scoreAtAction;
  final int? dueAtAction;

  Map<String, dynamic> toJson() => {
        'state': action.wireState,
        if (snoozedUntil != null)
          'snoozedUntil': snoozedUntil!.toUtc().toIso8601String(),
        if (scoreAtAction != null) 'scoreAtAction': scoreAtAction,
        if (dueAtAction != null) 'dueAtAction': dueAtAction,
      };
}
