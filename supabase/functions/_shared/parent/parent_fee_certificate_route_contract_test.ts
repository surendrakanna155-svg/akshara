// PAR-D3 — GET /parent/fee-certificate persona + own-child route contract.
//
// The annual / 80C fee-payment certificate DATA endpoint is parent-scoped and
// serves the caller's OWN child only. This drives the REAL router (routeParent)
// end to end — path → handler → auth/scope/own-child gates — using the
// established DB-free route-contract pattern: with no ERP_TENANT_DATABASE_URL
// configured, a request that PASSES every gate reaches the tenant DB and returns
// 503 (TENANT_DB_NOT_CONFIGURED). A request DENIED at a gate returns 401/403
// BEFORE any DB access, so a 503 vs 403/401 cleanly separates "authorized" from
// "denied".
//
// Proven:
//   • unauthenticated              → 401
//   • non-parent persona (teacher/student) → 403 (parent scope required)
//   • parent whose activeChildId ∉ child_ids → 403 (own-child guard, no leak)
//   • parent with NO linked children → 403
//   • parent + default first child   → 503 (passes gate, reaches DB)
//   • parent + a linked activeChildId → 503 (passes gate, reaches DB)
//   • the route is GET-only          → POST does not match (null)

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { matchParentRoute, routeParent } from "./parent_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function base(over: Partial<AccessTokenClaims>): AccessTokenClaims {
  return {
    sub: "user-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "teacher",
    role_slugs: ["teacher"],
    primary_role: "teacher",
    permissions: [],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

const teacher = () =>
  base({ scope: "school", primary_role: "teacher", role: "teacher" });
const student = () =>
  base({
    scope: "student",
    student_id: "student-1",
    primary_role: "student",
    role: "student",
    role_slugs: ["student"],
  });
const parent = (childIds: string[]) =>
  base({
    scope: "parent",
    child_ids: childIds,
    primary_role: "parent",
    role: "parent",
    role_slugs: ["parent"],
  });

async function get(
  c: AccessTokenClaims | null,
  path: string,
): Promise<Response | null> {
  const headers: Record<string, string> = {};
  if (c) headers.authorization = `Bearer ${await signAccessToken(SECRET, c, 900)}`;
  const req = new Request(`https://x${path}`, { method: "GET", headers });
  const routePathname = new URL(`https://x${path}`).pathname;
  return routeParent(req, config, "GET", routePathname);
}

Deno.test("PAR-D3: fee-certificate route matches GET and binds handleFeeCertificate", () => {
  const match = matchParentRoute("GET", "/parent/fee-certificate");
  assertEquals(match?.handler.name, "handleFeeCertificate");
  // GET-only: a POST must not match the certificate read.
  assertEquals(matchParentRoute("POST", "/parent/fee-certificate"), null);
});

Deno.test("PAR-D3: fee-certificate rejects an unauthenticated caller (401)", async () => {
  const res = await get(null, "/parent/fee-certificate?academicYear=2025-2026");
  assertEquals(res?.status, 401);
});

Deno.test("PAR-D3: fee-certificate denies a non-parent persona (403)", async () => {
  for (const c of [teacher(), student()]) {
    const res = await get(c, "/parent/fee-certificate?academicYear=2025-2026");
    assertEquals(res?.status, 403, `scope ${c.scope} must not read a fee certificate`);
  }
});

Deno.test("PAR-D3: fee-certificate denies an activeChildId NOT linked to the parent (403, no leak)", async () => {
  const res = await get(
    parent(["my-child"]),
    "/parent/fee-certificate?academicYear=2025-2026&activeChildId=someone-elses-child",
  );
  assertEquals(res?.status, 403);
});

Deno.test("PAR-D3: fee-certificate denies a parent with no linked children (403)", async () => {
  const res = await get(parent([]), "/parent/fee-certificate?academicYear=2025-2026");
  assertEquals(res?.status, 403);
});

Deno.test("PAR-D3: fee-certificate passes for the parent's default child and reaches the DB (503)", async () => {
  const res = await get(parent(["my-child"]), "/parent/fee-certificate?academicYear=2025-2026");
  assertEquals(res?.status, 503);
});

Deno.test("PAR-D3: fee-certificate passes for an explicitly-linked activeChildId (503)", async () => {
  const res = await get(
    parent(["my-child", "my-other-child"]),
    "/parent/fee-certificate?year=2025&activeChildId=my-other-child",
  );
  assertEquals(res?.status, 503);
});
