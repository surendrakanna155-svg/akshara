import { assertEquals } from "jsr:@std/assert@1";
import { matchAcademicRoute } from "./academic_router.ts";

Deno.test("academic router exposes transition preview route", () => {
  const match = matchAcademicRoute("POST", "/academic/transitions/preview");
  assertEquals(match?.handler.name, "handlePreviewTransition");
});

Deno.test("academic router exposes transition execute route", () => {
  const match = matchAcademicRoute(
    "POST",
    "/academic/transitions/ce100000-0000-4000-8000-000000000099/execute",
  );
  assertEquals(match?.handler.name, "handleExecuteTransition");
  assertEquals(match?.args[0], "ce100000-0000-4000-8000-000000000099");
});

Deno.test("academic router exposes mapping suggestions route", () => {
  const match = matchAcademicRoute("GET", "/academic/transitions/mapping-suggestions");
  assertEquals(match?.handler.name, "handleSuggestTransitionMappings");
});

Deno.test("v8.0 migration defines academic_year_transitions table", async () => {
  const sql = await Deno.readTextFile(
    new URL("../../../migrations/20260619000000_academic_year_transition_engine.sql", import.meta.url),
  );
  assertEquals(sql.includes("CREATE TABLE academic_year_transitions"), true);
  assertEquals(sql.includes("class_mapping JSONB"), true);
});
