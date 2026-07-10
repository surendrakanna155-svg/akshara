import { assert, assertEquals } from "jsr:@std/assert@1";
import { matchCopilotRoute } from "./copilot_router.ts";

Deno.test("GET /copilot/economics is registered", () => {
  const match = matchCopilotRoute("GET", "/copilot/economics");
  assert(match !== null);
  assertEquals(match?.args, []);
});

Deno.test("/copilot/economics rejects non-GET methods", () => {
  assertEquals(matchCopilotRoute("POST", "/copilot/economics"), null);
});
