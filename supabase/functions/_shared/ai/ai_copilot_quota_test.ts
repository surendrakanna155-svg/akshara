// Adaptive AI — P3-AI-2 / W2 governance: per-role copilot quota tests (pure).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  copilotQuotaExceeded,
  copilotQuotaMessage,
  roleDailyCopilotLimit,
  startOfUtcDayIso,
} from "./ai_copilot_quota.ts";

Deno.test("role limits: students/parents lowest, staff higher, unknown = default", () => {
  assertEquals(roleDailyCopilotLimit("student"), 10);
  assertEquals(roleDailyCopilotLimit("parent"), 10);
  assertEquals(roleDailyCopilotLimit("teacher"), 20);
  assertEquals(roleDailyCopilotLimit("principal"), 30);
  assertEquals(roleDailyCopilotLimit("someUnmappedRole"), 30); // default
});

Deno.test("env override caps ALL roles when set", () => {
  Deno.env.set("AI_COPILOT_DAILY_LIMIT", "5");
  try {
    assertEquals(roleDailyCopilotLimit("teacher"), 5);
    assertEquals(roleDailyCopilotLimit("student"), 5);
  } finally {
    Deno.env.delete("AI_COPILOT_DAILY_LIMIT");
  }
});

Deno.test("quota decision: at-or-over the limit is exceeded", () => {
  assertEquals(copilotQuotaExceeded(0, 10), false);
  assertEquals(copilotQuotaExceeded(9, 10), false);
  assertEquals(copilotQuotaExceeded(10, 10), true); // at the cap
  assertEquals(copilotQuotaExceeded(11, 10), true);
});

Deno.test("start-of-UTC-day truncates the time", () => {
  const iso = startOfUtcDayIso(new Date("2026-07-10T14:37:09.123Z"));
  assertEquals(iso, "2026-07-10T00:00:00.000Z");
});

Deno.test("quota message names the limit and reassures deterministic surfaces", () => {
  const msg = copilotQuotaMessage(20);
  assertEquals(msg.includes("20 messages"), true);
  assertEquals(/dashboards|search|reports/i.test(msg), true);
});
