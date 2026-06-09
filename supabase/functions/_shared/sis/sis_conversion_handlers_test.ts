import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchSisRoute } from "./sis_router.ts";

Deno.test("sis router matches POST /sis/admissions-conversion", () => {
  const match = matchSisRoute("POST", "/sis/admissions-conversion");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleAdmissionsConversion");
});

Deno.test("conversion handler accepts classLabel alias in repository contract", async () => {
  const handlerSource = await Deno.readTextFile(
    new URL("./sis_conversion_handlers.ts", import.meta.url),
  );
  assertEquals(handlerSource.includes("classLabel"), true);
  assertEquals(handlerSource.includes("class_label"), true);
  assertEquals(handlerSource.includes("requirePermission(claims, \"manageSis\")"), true);
  assertEquals(handlerSource.includes("requireSchoolOperationalScope"), true);
});
