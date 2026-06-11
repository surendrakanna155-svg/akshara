import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchIntelligenceRoute } from "./intelligence_router.ts";

Deno.test("intelligence router matches risk compute", () => {
  const match = matchIntelligenceRoute("POST", "/intelligence/risk/students/compute");
  assertEquals(match?.args.length, 0);
});

Deno.test("intelligence router matches principal center", () => {
  const match = matchIntelligenceRoute("GET", "/intelligence/principal/center");
  assertEquals(match?.args.length, 0);
});

Deno.test("intelligence router matches teacher effectiveness lesson scores", () => {
  const match = matchIntelligenceRoute("GET", "/intelligence/teacher-effectiveness/lesson-scores");
  assertEquals(match?.args.length, 0);
});

Deno.test("intelligence router matches parent meeting summary POST", () => {
  const match = matchIntelligenceRoute(
    "POST",
    "/intelligence/teacher-effectiveness/parent-meeting-summary",
  );
  assertEquals(match?.args.length, 0);
});

Deno.test("intelligence router matches student success dashboard", () => {
  const match = matchIntelligenceRoute("GET", "/intelligence/student-success/dashboard");
  assertEquals(match?.args.length, 0);
});

Deno.test("intelligence router matches exam analytics", () => {
  const match = matchIntelligenceRoute("GET", "/intelligence/exam/analytics");
  assertEquals(match?.args.length, 0);
});

Deno.test("intelligence router matches student success by id", () => {
  const match = matchIntelligenceRoute(
    "GET",
    "/intelligence/student-success/students/f0500000-0000-4000-8000-000000000001",
  );
  assertEquals(match?.args[0], "f0500000-0000-4000-8000-000000000001");
});
