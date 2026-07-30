import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { reporterSafeEvents } from "./support_handlers.ts";
import type { EventRow } from "./support_types.ts";

function ev(event_type: string, metadata: Record<string, unknown> = {}): EventRow {
  return {
    id: crypto.randomUUID(),
    incident_id: "i1",
    event_type,
    actor_user_id: "u1",
    from_value: null,
    to_value: null,
    metadata,
    created_at: "2026-07-20T10:00:00Z",
  };
}

Deno.test("reporterSafeEvents hides support-internal events from the reporter timeline", () => {
  const events: EventRow[] = [
    ev("created"),
    ev("evidence_collected", { signals: ["recent 403"] }),
    ev("ai_analyzed", { version: 1 }),
    ev("ai_analysis_approved", { version: 1 }),
    ev("message_posted", { visibility: "internal_note" }),
    ev("message_posted", { visibility: "school_visible" }),
    ev("status_changed"),
    ev("resolved"),
  ];
  const safe = reporterSafeEvents(events);
  const types = safe.map((e) => e.event_type);

  // support-internal analysis/evidence never surface to the reporter
  assertEquals(types.includes("evidence_collected"), false);
  assertEquals(types.includes("ai_analyzed"), false);
  assertEquals(types.includes("ai_analysis_approved"), false);
  // the internal-note message_posted is dropped; the school-visible one stays
  assertEquals(types.filter((t) => t === "message_posted").length, 1);
  // reporter-relevant lifecycle events remain
  assertEquals(types.includes("created"), true);
  assertEquals(types.includes("status_changed"), true);
  assertEquals(types.includes("resolved"), true);
  // metadata is stripped (no signals/version leakage)
  assertEquals(safe.every((e) => !("metadata" in e)), true);
});
