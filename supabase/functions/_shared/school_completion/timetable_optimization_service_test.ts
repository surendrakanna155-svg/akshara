import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computeQualityScore } from "./timetable_optimization_service.ts";

Deno.test("computeQualityScore penalizes conflicts and overload", () => {
  assertEquals(
    computeQualityScore({ conflictCount: 0, overloadCount: 0, gapCount: 0, timetableCount: 5 }),
    100,
  );
  assertEquals(
    computeQualityScore({ conflictCount: 2, overloadCount: 1, gapCount: 3, timetableCount: 5 }),
    54,
  );
  assertEquals(
    computeQualityScore({ conflictCount: 0, overloadCount: 0, gapCount: 0, timetableCount: 0 }),
    0,
  );
});
