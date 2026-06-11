import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { detectPrincipalQueryIntent } from "./principal_query_service.ts";

Deno.test("detectPrincipalQueryIntent matches attendance queries", () => {
  assertEquals(
    detectPrincipalQueryIntent("Show students below 75% attendance"),
    "low_attendance",
  );
});

Deno.test("detectPrincipalQueryIntent matches risk queries", () => {
  assertEquals(detectPrincipalQueryIntent("high-risk students"), "high_risk");
});

Deno.test("detectPrincipalQueryIntent matches fee queries", () => {
  assertEquals(detectPrincipalQueryIntent("fee defaulters pending"), "fee_defaulters");
});

Deno.test("detectPrincipalQueryIntent matches homework queries", () => {
  assertEquals(detectPrincipalQueryIntent("homework gaps missing"), "homework_gaps");
});
