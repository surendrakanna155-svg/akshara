import { assert, assertEquals } from "jsr:@std/assert@1";
import type { FactSignalUpsert } from "./ai_fact_signals_repository.ts";
import {
  eventFamily,
  eventToEntityTags,
  eventToSignal,
  refineEvents,
  type RefineryDeps,
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
