// Adaptive AI — P3-AI-2 / W2.0b: pre-staged action registry tests (pure, DB-free).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { actionForItem } from "./recommendation_actions.ts";
import type { RawPriorityItem } from "./priority_types.ts";

function item(over: Partial<RawPriorityItem>): RawPriorityItem {
  return {
    itemKey: "k",
    type: "exception",
    title: "t",
    detail: "d",
    personas: ["principal"],
    entityTags: [],
    factors: {},
    source: "student_risk",
    ...over,
  };
}

Deno.test("every produced action requires human confirmation (AI never executes)", () => {
  const sources = ["fee_collection", "student_risk", "timetable_health", "attendance_risk", "analytics_risk"];
  for (const source of sources) {
    const action = actionForItem(item({ source, itemKey: `${source}:x` }));
    assert(action, `expected an action for ${source}`);
    assertEquals(action.requiresConfirmation, true);
  }
});

Deno.test("student_risk action deep-links to the specific student", () => {
  const action = actionForItem(item({ source: "student_risk", itemKey: "risk:student:abc-123" }));
  assertEquals(action?.deepLink, "/intelligence/risk/students/abc-123");
  assertEquals(action?.payload, { studentId: "abc-123" });
});

Deno.test("fee_collection action opens the recovery call queue", () => {
  const action = actionForItem(item({ source: "fee_collection", itemKey: "fee:collection" }));
  assertEquals(action?.deepLink, "/finance/recovery/call-queue");
});

Deno.test("finance-tagged analytics risk routes to recovery, others to analytics", () => {
  const fin = actionForItem(item({ source: "analytics_risk", entityTags: ["school:fees"] }));
  assertEquals(fin?.deepLink, "/finance/recovery/call-queue");
  const other = actionForItem(item({ source: "analytics_risk", entityTags: ["school:analytics"] }));
  assertEquals(other?.deepLink, "/analytics/dashboard");
});

Deno.test("an unknown source yields no action (informational only)", () => {
  assertEquals(actionForItem(item({ source: "some_future_source" })), undefined);
});
