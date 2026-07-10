// Adaptive AI — W2: shared feed date math tests (pure, DB-free). P2-7 IST fix.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { dueInDaysFrom } from "./feed_dates.ts";

Deno.test("dueInDaysFrom: undefined when the due date is missing/unparseable", () => {
  assertEquals(dueInDaysFrom("2026-07-10T00:00:00Z", null), undefined);
  assertEquals(dueInDaysFrom("2026-07-10T00:00:00Z", undefined), undefined);
  assertEquals(dueInDaysFrom("2026-07-10T00:00:00Z", "not-a-date"), undefined);
});

Deno.test("dueInDaysFrom: same-day and simple offsets on the IST calendar", () => {
  const now = "2026-07-10T06:00:00Z"; // 11:30 IST, 10 Jul
  assertEquals(dueInDaysFrom(now, "2026-07-10"), 0); // due today
  assertEquals(dueInDaysFrom(now, "2026-07-11"), 1); // tomorrow
  assertEquals(dueInDaysFrom(now, "2026-07-08"), -2); // overdue
});

Deno.test("P2-7: the late-UTC / early-IST window uses the IST calendar day", () => {
  // 2026-07-10T20:00Z is 2026-07-11 01:30 IST — "today" in IST is the 11th.
  const lateUtc = "2026-07-10T20:00:00Z";
  assertEquals(dueInDaysFrom(lateUtc, "2026-07-11"), 0); // due today (IST), not +1
  assertEquals(dueInDaysFrom(lateUtc, "2026-07-10"), -1); // overdue since IST midnight
});
