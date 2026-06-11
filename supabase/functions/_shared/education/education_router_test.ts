import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchEducationRoute } from "./education_router.ts";

Deno.test("education router matches question bank list", () => {
  const match = matchEducationRoute("GET", "/education/question-bank");
  assertEquals(match?.args.length, 0);
});

Deno.test("education router matches question paper generate", () => {
  const match = matchEducationRoute("POST", "/education/question-papers/generate");
  assertEquals(match?.args.length, 0);
});

Deno.test("education router matches homework publish with uuid", () => {
  const id = "e0500000-0000-4000-8000-000000000099";
  const match = matchEducationRoute("POST", `/education/homework/${id}/publish`);
  assertEquals(match?.args[0], id);
});

Deno.test("education router returns null for unknown path", () => {
  const match = matchEducationRoute("GET", "/education/unknown");
  assertEquals(match, null);
});
