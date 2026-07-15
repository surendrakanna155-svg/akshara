import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildPendingAlerts,
  computeDaysPending,
  type ProgressTopicRow,
} from "./academic_tracking_service.ts";

// P1 fix (cap 65) — `pendingAlerts[].daysPending` used to be a hardcoded `7`
// regardless of how long a topic had actually been outstanding. These tests
// prove it is now a real computation from `syllabus_topics.created_at`.

Deno.test("computeDaysPending returns 0 for a topic created today", () => {
  const now = new Date("2026-07-15T12:00:00Z");
  assertEquals(computeDaysPending("2026-07-15T01:00:00Z", now), 0);
});

Deno.test("computeDaysPending returns the real elapsed day count", () => {
  const now = new Date("2026-07-15T12:00:00Z");
  assertEquals(computeDaysPending("2026-07-01T12:00:00Z", now), 14);
  assertEquals(computeDaysPending("2026-06-15T12:00:00Z", now), 30);
});

Deno.test("computeDaysPending never goes negative for a future timestamp", () => {
  const now = new Date("2026-07-15T00:00:00Z");
  assertEquals(computeDaysPending("2026-07-20T00:00:00Z", now), 0);
});

Deno.test("buildPendingAlerts excludes completed topics and computes real daysPending per topic", () => {
  const now = new Date("2026-07-15T00:00:00Z");
  const topics: ProgressTopicRow[] = [
    {
      id: "top1",
      status: "pending",
      topic_name: "Fractions",
      class_name: "Grade 7",
      subject_id: "sub_2",
      created_at: "2026-07-01T00:00:00Z", // 14 days pending
    },
    {
      id: "top2",
      status: "completed",
      topic_name: "Decimals",
      class_name: "Grade 7",
      subject_id: "sub_2",
      created_at: "2026-06-01T00:00:00Z",
    },
    {
      id: "top3",
      status: "pending",
      topic_name: "Algebra",
      class_name: "Grade 8",
      subject_id: "sub_2",
      created_at: "2026-07-10T00:00:00Z", // 5 days pending, but completed via completions set
    },
  ];

  const alerts = buildPendingAlerts(topics, new Set(["top3"]), now);

  assertEquals(alerts.length, 1);
  assertEquals(alerts[0]!.topicName, "Fractions");
  assertEquals(alerts[0]!.daysPending, 14);
});

Deno.test("buildPendingAlerts caps the alert list at 10 entries", () => {
  const now = new Date("2026-07-15T00:00:00Z");
  const topics: ProgressTopicRow[] = Array.from({ length: 15 }, (_, i) => ({
    id: `top${i}`,
    status: "pending",
    topic_name: `Topic ${i}`,
    class_name: "Grade 7",
    subject_id: "sub_1",
    created_at: "2026-07-01T00:00:00Z",
  }));

  const alerts = buildPendingAlerts(topics, new Set(), now);
  assertEquals(alerts.length, 10);
});
