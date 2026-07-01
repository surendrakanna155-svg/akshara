import {
  assert,
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchCommunicationRoute } from "./communication_router.ts";
import {
  handleCreateBroadcast,
  handleRunScheduledBroadcasts,
} from "./communication_handlers.ts";
import {
  CommunicationValidationError,
  parseScheduledAt,
} from "./communication_service.ts";

// XCT-2: scheduled-broadcast foundation. DB-free coverage — route registration
// (so the cron/ops entry point can't silently regress to a 404) + the pure
// scheduledAt validator that gates every scheduled write.

Deno.test("XCT-2: POST /communications/broadcasts/run-scheduled resolves to the runner", () => {
  const match = matchCommunicationRoute(
    "POST",
    "/communications/broadcasts/run-scheduled",
  );
  assert(match !== null, "run-scheduled must resolve");
  assertEquals(match!.handler, handleRunScheduledBroadcasts);
});

Deno.test("XCT-2: POST /communications/broadcasts still resolves to create (unchanged)", () => {
  const match = matchCommunicationRoute("POST", "/communications/broadcasts");
  assert(match !== null);
  assertEquals(match!.handler, handleCreateBroadcast);
});

Deno.test("XCT-2: run-scheduled only accepts POST", () => {
  assertEquals(
    matchCommunicationRoute("GET", "/communications/broadcasts/run-scheduled"),
    null,
  );
  assertEquals(
    matchCommunicationRoute("DELETE", "/communications/broadcasts/run-scheduled"),
    null,
  );
});

Deno.test("parseScheduledAt normalizes a valid timestamp to UTC ISO", () => {
  assertEquals(parseScheduledAt("2026-08-01T09:30:00Z"), "2026-08-01T09:30:00.000Z");
  // Date-only is a valid Date (midnight UTC) — accepted.
  assertEquals(parseScheduledAt("2026-08-01"), "2026-08-01T00:00:00.000Z");
});

Deno.test("parseScheduledAt rejects empty / whitespace", () => {
  assertThrows(() => parseScheduledAt(""), CommunicationValidationError);
  assertThrows(() => parseScheduledAt("   "), CommunicationValidationError);
  assertThrows(() => parseScheduledAt(null), CommunicationValidationError);
  assertThrows(() => parseScheduledAt(undefined), CommunicationValidationError);
});

Deno.test("parseScheduledAt rejects an unparseable timestamp", () => {
  assertThrows(() => parseScheduledAt("not-a-date"), CommunicationValidationError);
  assertThrows(() => parseScheduledAt("2026-13-99"), CommunicationValidationError);
});
