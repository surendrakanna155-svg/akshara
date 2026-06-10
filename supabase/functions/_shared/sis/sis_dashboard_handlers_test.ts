import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchSisRoute } from "./sis_router.ts";

Deno.test("sis router matches GET /sis/dashboard", () => {
  const match = matchSisRoute("GET", "/sis/dashboard");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleDashboard");
});

Deno.test("dashboard handler requires viewSis and school scope", async () => {
  const handlerSource = await Deno.readTextFile(
    new URL("./sis_dashboard_handlers.ts", import.meta.url),
  );
  assertEquals(handlerSource.includes('requirePermission(claims, "viewSis")'), true);
  assertEquals(handlerSource.includes("requireSchoolOperationalScope"), true);
  assertEquals(handlerSource.includes("withTenantContext"), true);
});
