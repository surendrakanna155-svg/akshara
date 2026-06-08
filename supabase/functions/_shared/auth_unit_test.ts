import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { permissionsForRole } from "./permissions.ts";
import { envelope, routePath } from "./http.ts";
import { hashToken } from "./jwt.ts";

Deno.test("permissionsForRole returns schoolAdmin permissions", () => {
  const perms = permissionsForRole("schoolAdmin");
  assertEquals(perms.includes("manageFinance"), true);
  assertEquals(perms.includes("viewAdminHub"), true);
});

Deno.test("envelope wraps data", () => {
  const wrapped = envelope({ status: "ok" });
  assertEquals(wrapped.error, null);
  assertExists(wrapped.data);
});

Deno.test("routePath strips function prefix", () => {
  const req = new Request("http://localhost/functions/v1/api/auth/login");
  assertEquals(routePath(req), "/auth/login");
});

Deno.test("hashToken is deterministic", async () => {
  const a = await hashToken("123456");
  const b = await hashToken("123456");
  assertEquals(a, b);
  assertEquals(a.length, 64);
});
