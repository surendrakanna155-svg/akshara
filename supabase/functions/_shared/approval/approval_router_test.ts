import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { routeApproval } from "./approval_router.ts";
import { loadConfig } from "../config.ts";

const config = loadConfig();

function mockRequest(method: string, path: string): Request {
  return new Request(`https://example.com/api${path}`, { method });
}

Deno.test("approval router matches pending list route", async () => {
  const response = await routeApproval(
    mockRequest("GET", "/approvals/pending"),
    config,
    "GET",
    "/approvals/pending",
  );
  assertEquals(response != null, true);
  assertEquals(response!.status, 401);
});

Deno.test("approval router returns null for unrelated paths", async () => {
  const response = await routeApproval(
    mockRequest("GET", "/finance/refunds"),
    config,
    "GET",
    "/finance/refunds",
  );
  assertEquals(response, null);
});

Deno.test("approval router matches entity lookup route", async () => {
  const response = await routeApproval(
    mockRequest("GET", "/approvals/entity"),
    config,
    "GET",
    "/approvals/entity",
  );
  assertEquals(response != null, true);
});
