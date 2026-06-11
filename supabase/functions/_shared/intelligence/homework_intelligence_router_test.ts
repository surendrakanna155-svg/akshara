import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchIntelligenceRoute } from "./intelligence_router.ts";

Deno.test("intelligence router matches homework intelligence plan", () => {
  const match = matchIntelligenceRoute("GET", "/intelligence/homework-intelligence/plan");
  assertEquals(match?.handler.name, "handleHomeworkIntelligencePlan");
});

Deno.test("intelligence router matches homework intelligence generate", () => {
  const match = matchIntelligenceRoute("POST", "/intelligence/homework-intelligence/generate");
  assertEquals(match?.handler.name, "handleHomeworkIntelligenceGenerate");
});
