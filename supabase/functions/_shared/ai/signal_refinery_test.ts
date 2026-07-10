import { assert, assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { FactSignalUpsert } from "./ai_fact_signals_repository.ts";
import {
  eventFamily,
  eventToEntityTags,
  eventToSignal,
  refineEvents,
  type RefineryDeps,
  runSignalRefinery,
} from "./signal_refinery.ts";

Deno.test("eventFamily classifies the known families and ignores the rest", () => {
  assertEquals(eventFamily("fee_collected"), "fees");
  assertEquals(eventFamily("finance.payment.recorded"), "fees");
  assertEquals(eventFamily("attendance_marked"), "attendance");
  assertEquals(eventFamily("exam_results_published"), "exams");
  assertEquals(eventFamily("approval_requested"), "approvals");
  assertEquals(eventFamily("teacher_logged_in"), null);
});

Deno.test("eventFamily covers the broadened families (F19)", () => {
  assertEquals(eventFamily("education.homework.published"), "homework");
  assertEquals(eventFamily("library.book.issued"), "library");
  assertEquals(eventFamily("inventory.stock.issued"), "inventory");
  assertEquals(eventFamily("transport.route.created"), "transport");
  assertEquals(eventFamily("admissions.lead.stage_changed"), "admissions");
});

Deno.test("eventFamily does not misclassify transport/HR attendance as academic (F19)", () => {
  // Bus attendance is transport, not academic class attendance.
  assertEquals(eventFamily("transport.attendance.recorded"), "transport");
  // Biometric HR attendance carries no academic cache/signal dependency.
  assertEquals(eventFamily("staff_attendance.check_in.recorded"), null);
  // Academic class attendance still classifies correctly.
  assertEquals(eventFamily("attendance.submitted"), "attendance");
});

Deno.test("eventToEntityTags emits school + student tags for a student-scoped event", () => {
  assertEquals(
    eventToEntityTags("fee_collected", { student_id: "stu-1" }),
    ["school:fees", "student:stu-1:fees"],
  );
  assertEquals(eventToEntityTags("fee_collected", {}), ["school:fees"]);
  assertEquals(eventToEntityTags("unrelated_event", { student_id: "stu-1" }), []);
});

Deno.test("eventToSignal targets the right signal + scope, or null", () => {
  assertEquals(eventToSignal("attendance_marked", { studentId: "stu-9" }), {
    signalType: "attendance_activity",
    scopeKey: "student:stu-9",
    payload: { lastEventType: "attendance_marked", source: "signal_refinery" },
  });
  assertEquals(eventToSignal("fee_collected", {})?.scopeKey, "school");
  assertEquals(eventToSignal("nothing_relevant", {}), null);
});

function captureDeps(invalidatedPerCall = 1): {
  deps: RefineryDeps;
  invalidations: string[][];
  signals: FactSignalUpsert[];
} {
  const invalidations: string[][] = [];
  const signals: FactSignalUpsert[] = [];
  return {
    invalidations,
    signals,
    deps: {
      invalidate: (tags) => {
        invalidations.push(tags);
        return Promise.resolve(invalidatedPerCall);
      },
      touchSignal: (s) => {
        signals.push(s);
        return Promise.resolve();
      },
    },
  };
}

Deno.test("refineEvents invalidates cache + touches signals; ignores irrelevant events", async () => {
  const { deps, invalidations, signals } = captureDeps(2);
  const result = await refineEvents([
    { eventType: "fee_collected", payload: { student_id: "stu-1" } },
    { eventType: "attendance_marked", payload: { studentId: "stu-2" } },
    { eventType: "teacher_logged_in", payload: {} }, // irrelevant → skipped
  ], deps);
  assertEquals(result.processed, 3);
  assertEquals(result.signalsTouched, 2);
  assertEquals(result.cacheEntriesInvalidated, 4); // 2 relevant events × 2 rows each
  assertEquals(invalidations.length, 2);
  assertEquals(signals.map((s) => s.signalType), ["fees_activity", "attendance_activity"]);
});

Deno.test("refineEvents is idempotent: replay derives identical operations", async () => {
  const events = [{ eventType: "fee_collected", payload: { student_id: "stu-1" } }];
  const first = captureDeps(1);
  await refineEvents(events, first.deps);
  const second = captureDeps(0); // cache already empty on replay → 0 removed
  await refineEvents(events, second.deps);
  assertEquals(first.invalidations, second.invalidations); // same tags derived
  assertEquals(first.signals, second.signals); // same signal upsert
});

// ── runSignalRefinery DB-path (watermark + savepoint isolation, H6) ──────────

interface RefEvent {
  event_type: string;
  payload: Record<string, unknown>;
  created_at: string;
}

/** Stateful fake tenant client simulating the exact SQL runSignalRefinery issues:
 * cursor read/write on ai_fact_signals, the domain_events window, SAVEPOINTs,
 * cache DELETE (optionally throwing for a tag), and signal upserts. */
function refineryDb(opts: { cursor?: string | null; events: RefEvent[]; failOnTag?: string }) {
  let cursor: string | null = opts.cursor ?? null;
  let invalidateCalls = 0;
  const upserts: string[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject: (sql: string, params?: any[]) => {
      const s = sql.trimStart();
      if (s.startsWith("SAVEPOINT") || s.startsWith("RELEASE") || s.startsWith("ROLLBACK")) {
        return Promise.resolve([]);
      }
      if (s.startsWith("SELECT") && sql.includes("FROM ai_fact_signals")) {
        return Promise.resolve(
          cursor
            ? [{ signal_type: "_refinery_cursor", scope_key: "_cursor", payload: { lastCreatedAt: cursor }, computed_at: "t" }]
            : [],
        );
      }
      if (sql.includes("FROM domain_events")) {
        const cur = params?.[2] as string | null;
        return Promise.resolve(opts.events.filter((e) => !cur || e.created_at > cur));
      }
      if (sql.includes("DELETE FROM ai_response_cache")) {
        const tags = params?.[2] as string[];
        if (opts.failOnTag && tags?.includes(opts.failOnTag)) {
          return Promise.reject(new Error("invalidate boom"));
        }
        invalidateCalls++;
        return Promise.resolve([{ id: "c1" }]); // 1 row invalidated
      }
      if (sql.includes("INSERT INTO ai_fact_signals")) {
        const signalType = params?.[2] as string;
        if (signalType === "_refinery_cursor") {
          const next = JSON.parse(params?.[4] as string).lastCreatedAt as string;
          if (!cursor || cursor < next) cursor = next; // monotonic (mirrors the WHERE)
          return Promise.resolve([]);
        }
        upserts.push(signalType);
        return Promise.resolve([]);
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
  return { db, cursor: () => cursor, invalidateCalls: () => invalidateCalls, upserts: () => upserts };
}

const SCOPE = { organizationId: "org-1", schoolId: "sch-1" };

Deno.test("runSignalRefinery processes new events, invalidates, and advances the watermark", async () => {
  const fx = refineryDb({
    events: [
      { event_type: "fee_collected", payload: { student_id: "s1" }, created_at: "2026-07-01T10:00:00.000Z" },
      { event_type: "attendance_marked", payload: { studentId: "s2" }, created_at: "2026-07-01T11:00:00.000Z" },
    ],
  });
  const r = await runSignalRefinery(fx.db, SCOPE);
  assertEquals(r.processed, 2);
  assertEquals(r.signalsTouched, 2);
  assertEquals(r.cacheEntriesInvalidated, 2);
  assertEquals(r.skipped, 0);
  assertEquals(fx.cursor(), "2026-07-01T11:00:00.000Z"); // advanced to the newest
});

Deno.test("runSignalRefinery is a no-op past its watermark (no re-processing)", async () => {
  const fx = refineryDb({
    cursor: "2026-07-01T11:00:00.000Z",
    events: [
      { event_type: "fee_collected", payload: {}, created_at: "2026-07-01T10:00:00.000Z" },
      { event_type: "attendance_marked", payload: {}, created_at: "2026-07-01T11:00:00.000Z" },
    ],
  });
  const r = await runSignalRefinery(fx.db, SCOPE);
  assertEquals(r.processed, 0);
});

Deno.test("runSignalRefinery isolates a failed event and stops the watermark at the last success (H5)", async () => {
  const fx = refineryDb({
    failOnTag: "school:attendance", // the middle (attendance) event's invalidate throws
    events: [
      { event_type: "fee_collected", payload: {}, created_at: "2026-07-01T10:00:00.000Z" },
      { event_type: "attendance_marked", payload: {}, created_at: "2026-07-01T11:00:00.000Z" },
      { event_type: "homework.assigned", payload: {}, created_at: "2026-07-01T12:00:00.000Z" },
    ],
  });
  const r = await runSignalRefinery(fx.db, SCOPE);
  assertEquals(r.skipped, 1);
  // Watermark stops at the fee event — the failed attendance event (and homework
  // after it) are re-consumed next run, not silently passed.
  assertEquals(fx.cursor(), "2026-07-01T10:00:00.000Z");
});
