// Adaptive AI — P3-AI-2 / W2.S: Universal Search route contract (DB-free).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { parseOffset } from "./search_handlers.ts";
import { orderResults, toFinanceInvoiceResult } from "./search_ranking.ts";
import { searchClasses, searchFinanceInvoices } from "./search_repository.ts";
import { routeSearch } from "./search_router.ts";
import type { SearchGroup } from "./search_types.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "principal", role_slugs: ["principal"], primary_role: "principal",
    permissions: perms, permissions_version: 1, scope: "school",
    school_group_id: null, student_id: null, child_ids: [], session_id: "s1", ...over,
  };
}

async function call(
  method: string,
  path: string,
  perms: string[],
  over: Partial<AccessTokenClaims> = {},
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  const pathname = path.split("?")[0]!;
  return await routeSearch(
    new Request(`https://x${path}`, { method, headers: { authorization: `Bearer ${token}` } }),
    config,
    method,
    pathname,
  );
}

Deno.test("W2.S: a permitted search reaches the DB (503 unconfigured = authorized+matched)", async () => {
  const res = await call("GET", "/search?q=ram", ["viewSis"]);
  assertEquals(res?.status, 503);
});

Deno.test("W2.S: a caller with NO searchable-category permission gets an empty result (200)", async () => {
  // No viewSis/viewEmployees/viewAdmissions → all categories filtered → empty.
  const res = await call("GET", "/search?q=ram", ["someOtherPerm"]);
  assertEquals(res?.status, 200);
  const env = await res!.json();
  assertEquals(env.data.groups, []);
});

Deno.test("W2.S: staff/admissions categories require their own ERP permission", async () => {
  // viewEmployees alone authorizes the staff category → reaches DB (503).
  assertEquals((await call("GET", "/search?q=priya", ["viewEmployees"]))?.status, 503);
  // viewAdmissions alone authorizes the admissions category → reaches DB (503).
  assertEquals((await call("GET", "/search?q=arjun", ["viewAdmissions"]))?.status, 503);
  // A permission for a DIFFERENT module does not unlock any category → empty 200.
  const other = await call("GET", "/search?q=ram", ["viewTransport"]);
  assertEquals(other?.status, 200);
  assertEquals((await other!.json()).data.groups, []);
});

Deno.test("W2.S: a too-short query is rejected (422 before DB)", async () => {
  const res = await call("GET", "/search?q=r", ["viewSis"]);
  assertEquals(res?.status, 422);
});

Deno.test("W2.S: a missing query is rejected (422)", async () => {
  const res = await call("GET", "/search", ["viewSis"]);
  assertEquals(res?.status, 422);
});

Deno.test("W2.S: a non-school scope is forbidden (403)", async () => {
  const res = await call("GET", "/search?q=ram", ["viewSis"], { scope: "organization", school_id: null });
  assertEquals(res?.status, 403);
});

Deno.test("W2.S: an unauthenticated caller is rejected (401)", async () => {
  const res = await routeSearch(
    new Request("https://x/search?q=ram", { method: "GET" }),
    config,
    "GET",
    "/search",
  );
  assertEquals(res?.status, 401);
});

Deno.test("W2.S: a non-GET method is rejected (405)", async () => {
  const res = await call("POST", "/search?q=ram", ["viewSis"]);
  assertEquals(res?.status, 405);
});

Deno.test("W2.S: a non-/search path returns null (no match)", async () => {
  const res = await call("GET", "/intelligence/priorities", ["viewSis"]);
  assertEquals(res, null);
});

// ─── New categories: finance, communications, classes (RBAC gating) ─────────

Deno.test("W2.S: finance (Invoices) requires viewFinance", async () => {
  // viewFinance alone authorizes the finance category → reaches DB (503).
  assertEquals((await call("GET", "/search?q=inv-2026", ["viewFinance"]))?.status, 503);
  // A permission for a different module does not unlock it → empty 200.
  const other = await call("GET", "/search?q=inv-2026", ["viewTransport"]);
  assertEquals(other?.status, 200);
  assertEquals((await other!.json()).data.groups, []);
});

Deno.test("W2.S: communications (Communications) requires viewCommunications", async () => {
  // viewCommunications alone authorizes the communications category → reaches DB (503).
  assertEquals((await call("GET", "/search?q=annual", ["viewCommunications"]))?.status, 503);
  const other = await call("GET", "/search?q=annual", ["viewTransport"]);
  assertEquals(other?.status, 200);
  assertEquals((await other!.json()).data.groups, []);
});

Deno.test("W2.S: classes shares the students viewSis gate (no separate permission)", async () => {
  // classes is additive under the SAME viewSis permission that already unlocks
  // students — no new permission string is introduced for it.
  assertEquals((await call("GET", "/search?q=8-a", ["viewSis"]))?.status, 503);
  const other = await call("GET", "/search?q=8-a", ["viewTransport"]);
  assertEquals(other?.status, 200);
  assertEquals((await other!.json()).data.groups, []);
});

// ─── Offset pagination ───────────────────────────────────────────────────────

Deno.test("parseOffset: missing/invalid/negative input defaults to 0", () => {
  assertEquals(parseOffset(null), 0);
  assertEquals(parseOffset(""), 0);
  assertEquals(parseOffset("bad"), 0);
  assertEquals(parseOffset("-5"), 0);
});

Deno.test("parseOffset: a valid offset passes through; large offsets cap at 500", () => {
  assertEquals(parseOffset("42"), 42);
  assertEquals(parseOffset("500"), 500);
  assertEquals(parseOffset("10000"), 500);
});

Deno.test("W2.S: an invalid offset query param still reaches the DB (defaults to 0, doesn't 422)", async () => {
  const res = await call("GET", "/search?q=ram&offset=bad", ["viewSis"]);
  assertEquals(res?.status, 503); // authorized+matched, same as no offset at all
});

// Mock TenantQueryClient that captures the SQL + args passed to queryObject —
// follows the existing repository mock-db test style (e.g.
// intelligence/student_risk_repository_test.ts's SignalsMockDb): a plain class
// cast `as unknown as TenantQueryClient` since the real class has a private
// field and can't be satisfied structurally.
class CapturingMockDb {
  lastSql = "";
  lastArgs: unknown[] = [];
  constructor(private rows: Record<string, unknown>[]) {}
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    this.lastSql = sql;
    this.lastArgs = args;
    return this.rows as T[];
  }
  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
  get raw(): never {
    throw new Error("unused");
  }
}

Deno.test("offset is threaded into the finance repository SQL as an OFFSET clause", async () => {
  const db = new CapturingMockDb([]);
  await searchFinanceInvoices(db as unknown as TenantQueryClient, "org-1", "school-1", "inv", 8, 40);
  assertEquals(/OFFSET \$5/.test(db.lastSql), true);
  assertEquals(db.lastArgs, ["org-1", "school-1", "inv", 24, 40]); // cap=candidateCap(8)=24, offset=40
});

Deno.test("offset is threaded into the classes repository SQL as an OFFSET clause", async () => {
  const db = new CapturingMockDb([]);
  await searchClasses(db as unknown as TenantQueryClient, "org-1", "school-1", "8-a", 8, 16);
  assertEquals(/OFFSET \$5/.test(db.lastSql), true);
  assertEquals(db.lastArgs, ["org-1", "school-1", "8-a", 24, 16]);
});

Deno.test("offset defaults to 0 when a repository is called without it", async () => {
  const db = new CapturingMockDb([]);
  await searchFinanceInvoices(db as unknown as TenantQueryClient, "org-1", "school-1", "inv", 8);
  assertEquals(db.lastArgs[4], 0);
});

Deno.test("SearchGroup carries the requested offset (same composition the handler performs)", async () => {
  const requestedOffset = 8;
  const db = new CapturingMockDb([
    {
      id: "inv1",
      invoice_number: "INV-2026-0042",
      invoice_status: "issued",
      due_date: "2026-08-01",
      student_name: "Ramesh Kumar",
      total_matches: 12,
    },
  ]);
  const { candidates, total } = await searchFinanceInvoices(
    db as unknown as TenantQueryClient,
    "org-1",
    "school-1",
    "inv",
    8,
    requestedOffset,
  );
  const results = orderResults(candidates.map((c) => toFinanceInvoiceResult(c, "inv"))).slice(0, 8);
  // Mirrors exactly how handleUniversalSearch assembles each SearchGroup.
  const group: SearchGroup = {
    category: "finance",
    label: "Invoices",
    results,
    total,
    offset: requestedOffset,
  };
  assertEquals(group.offset, 8);
  assertEquals(group.total, 12);
  assertEquals(group.results[0]?.title, "INV-2026-0042");
});
