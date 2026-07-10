// W2.1 brief platform — pure unit tests (DB-free) + route contract checks.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  assembleBriefSections,
  briefCacheKey,
  secondsToNextIstPrewarm,
} from "./brief_service.ts";
import { buildFeed } from "../priority/priority_engine.ts";
import type { RawPriorityItem } from "../priority/priority_types.ts";
import { matchIntelligenceRoute } from "../intelligence_router.ts";

function raw(partial: Partial<RawPriorityItem> & { itemKey: string }): RawPriorityItem {
  return {
    type: "exception",
    title: partial.itemKey,
    detail: "",
    personas: ["principal"],
    entityTags: [],
    factors: {},
    source: "test",
    ...partial,
  } as RawPriorityItem;
}

Deno.test("sections: grouped by type in fixed order, empty sections omitted, counts honest", () => {
  const items = [
    raw({ itemKey: "a", type: "follow_up", title: "Chase fees" }),
    raw({ itemKey: "b", type: "exception", title: "Attendance unmarked" }),
    raw({ itemKey: "c", type: "exception", title: "Low stock" }),
    raw({ itemKey: "d", type: "deadline", title: "Marks due" }),
  ];
  const feed = buildFeed(items, "principal", "2026-07-11T03:00:00Z");
  const sections = assembleBriefSections(feed.items);

  assertEquals(sections.map((s) => s.title), [
    "Needs attention today",
    "Deadlines",
    "Follow-ups",
  ]);
  const attention = sections[0]!;
  assertEquals(attention.count, 2);
  assertEquals(attention.lines.length, 2);
});

Deno.test("sections: lines cap at 5 but the count reports everything", () => {
  const items = Array.from({ length: 8 }, (_, i) =>
    raw({ itemKey: `e${i}`, type: "deadline", title: `Deadline ${i}` }));
  const feed = buildFeed(items, "principal", "2026-07-11T03:00:00Z");
  const sections = assembleBriefSections(feed.items);
  assertEquals(sections.length, 1);
  assertEquals(sections[0]!.lines.length, 5);
  assertEquals(sections[0]!.count, 8);
});

Deno.test("sections: an empty feed yields an honest empty brief", () => {
  assertEquals(assembleBriefSections([]), []);
});

Deno.test("cache key: shared per (persona, scope, IST day) — no user id in the pulse key", () => {
  assertEquals(
    briefCacheKey("principal", "school", "2026-07-11"),
    "brief:principal:school:2026-07-11",
  );
  assertEquals(
    briefCacheKey("teacher", "user:u-1", "2026-07-11"),
    "brief:teacher:user:u-1:2026-07-11",
  );
});

Deno.test("prewarm TTL: expires at the next 04:00 IST, never in the past", () => {
  // 2026-07-11T03:00:00+05:30 == 2026-07-10T21:30:00Z → next 04:00 IST is 1h away.
  assertEquals(secondsToNextIstPrewarm("2026-07-10T21:30:00Z"), 3_600);
  // Exactly 04:00 IST → the NEXT day's window (24h).
  assertEquals(secondsToNextIstPrewarm("2026-07-10T22:30:00Z"), 24 * 3_600);
  // Mid-day IST → tomorrow 04:00.
  const midday = secondsToNextIstPrewarm("2026-07-11T06:30:00Z"); // 12:00 IST
  assertEquals(midday, 16 * 3_600);
});

// ─── Route contract ───────────────────────────────────────────────────────────

Deno.test("W2.1 routes are registered with the right methods", () => {
  assert(matchIntelligenceRoute("GET", "/intelligence/briefs/daily"));
  assert(matchIntelligenceRoute("POST", "/intelligence/briefs/prewarm"));
  assertEquals(matchIntelligenceRoute("POST", "/intelligence/briefs/daily"), null);
  assertEquals(matchIntelligenceRoute("GET", "/intelligence/briefs/prewarm"), null);
});
