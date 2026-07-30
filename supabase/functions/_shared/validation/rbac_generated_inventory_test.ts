// API-100 / API-102 / API-104 / OS-013 — **the inventory-completeness guard.**
//
// ## The mechanism this closes
//
// The RBAC inventory was hand-maintained, with no code-derived source and no
// test comparing it to the routers. Adding a route did not require touching it.
// The RBAC suite then iterated that same file, so a route added with no gate
// passed the whole suite *by not being listed* — which is exactly how two
// attendance routes shipped unaudited, and why 246 mutating routes
// (`POST /finance/collections`, `/finance/refunds`, every
// `/approvals/:id/{approve,reject,cancel}`, every `/academics/exams/*` mark
// write) were absent while the suite was green.
//
// This test re-derives the route table from the RUNNING DISPATCHER on every run
// and asserts the diff against the inventory is zero in both directions. There
// is no hand-maintained list left to drift: adding a route without re-running
// `scripts/rbac/rbac_inventory_report.ts` fails the build.
//
// ## What it would have reported before the fix
//
//   missing_from_inventory  246
//   rules_without_routes      3
//   outside_declared_prefix   7   (/domain-events/process-pending — API-104 —
//                                  plus /academic/teacher-assignments and
//                                  /academic/transitions, found by this guard)
//
// ## The honest boundary
//
// The derivation asks the dispatcher, so its ANSWERS are exact. Its QUESTIONS
// come from router source text plus the declared inventory, so a route that is
// both invisible to text extraction and absent from the inventory would not be
// asked about. `assertDerivationFloor` and the counts below exist so that blind
// spot cannot silently grow — a scan that stops matching fails loudly instead of
// proving nothing.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  assertDerivationFloor,
  deriveRouteTable,
  type DerivedRoute,
  mutatingRoutes,
  routeKey,
} from "./rbac_route_derivation.ts";
import {
  CURATED_RBAC_ROUTE_RULES,
  RBAC_ROUTE_INVENTORY,
} from "./rbac_route_inventory.ts";
import { DERIVED_RBAC_ROUTE_RULES } from "./rbac_derived_route_rules.ts";

// One derivation shared by every case in this file — it dispatches ~1,700
// requests and nothing about it varies per test.
let cachedTable: DerivedRoute[] | null = null;
async function table(): Promise<DerivedRoute[]> {
  if (cachedTable === null) {
    cachedTable = await deriveRouteTable();
    assertDerivationFloor(cachedTable);
  }
  return cachedTable;
}

Deno.test("API-100: the derivation itself is large enough to prove anything", async () => {
  const routes = await table();
  // Today: 867 routes / 415 mutating. The floor sits well below that so ordinary
  // route churn does not trip it, while a broken extractor does.
  assert(routes.length >= 550, `only ${routes.length} routes derived`);
  assert(
    mutatingRoutes(routes).length >= 280,
    `only ${mutatingRoutes(routes).length} mutating routes derived`,
  );
  // The routes the defect register named by hand must all be in scope.
  const keys = new Set(routes.map((r) => routeKey(r.method, r.path)));
  for (
    const [method, path] of [
      ["POST", "/finance/collections"],
      ["POST", "/finance/refunds"],
      ["POST", "/finance/day-close"],
      ["POST", "/approvals/:id/approve"],
      ["POST", "/approvals/:id/reject"],
      ["POST", "/approvals/:id/cancel"],
      ["PATCH", "/academics/exams/marks/:id"],
      ["PATCH", "/attendance/corrections/:id/status"],
      ["GET", "/audit/retention"],
      ["POST", "/domain-events/process-pending"],
    ] as const
  ) {
    assert(
      keys.has(routeKey(method, path)),
      `${method} ${path} is missing from the derived table — the derivation is ` +
        `not seeing routes it must see`,
    );
  }
});

Deno.test("API-100: every mutating route the dispatcher serves has an inventory rule", async () => {
  const inventory = new Set(
    RBAC_ROUTE_INVENTORY.map((r) => routeKey(r.method, r.path)),
  );
  const missing = mutatingRoutes(await table())
    .filter((r) => !inventory.has(routeKey(r.method, r.path)))
    .map((r) => `${r.method} ${r.path} [${r.module}]`);
  assertEquals(
    missing,
    [],
    `${missing.length} mutating route(s) exist with no inventory rule. Do NOT ` +
      `hand-add them — run:\n` +
      `  deno run --allow-read --allow-env scripts/rbac/rbac_inventory_report.ts\n` +
      `and paste its output into rbac_derived_route_rules.ts:\n${missing.join("\n")}`,
  );
});

Deno.test("API-102: every inventory rule names a route that still exists", async () => {
  const live = new Set((await table()).map((r) => routeKey(r.method, r.path)));
  const orphans = RBAC_ROUTE_INVENTORY
    .filter((r) => !live.has(routeKey(r.method, r.path)))
    .map((r) => `${r.method} ${r.path} [${r.module}]`);
  assertEquals(
    orphans,
    [],
    `${orphans.length} rule(s) describe routes no router answers. Anyone ` +
      `consulting the inventory to ask "what gates this?" would read a rule for ` +
      `a route that does not exist:\n${orphans.join("\n")}`,
  );
});

Deno.test("API-104 / OS-013: every route the dispatcher serves is inside a declared prefix", async () => {
  const outside = [
    ...new Set((await table()).filter((r) => r.module === "").map((r) => r.path)),
  ];
  assertEquals(
    outside,
    [],
    `MODULE_ROUTES declares the prefixes the single-ownership guard checks, so a ` +
      `path outside every prefix cannot be checked for double-ownership — the ` +
      `guarantee the registry exists to provide does not reach it. Add the ` +
      `prefix to the owning entry:\n${outside.join("\n")}`,
  );
});

Deno.test("API-100: the checked-in derived half matches a fresh derivation", async () => {
  // The property that makes the inventory a *generated artefact* rather than a
  // hand-maintained one: adding a route and not re-running the generator fails
  // here, naming the exact command.
  const live = new Set(
    mutatingRoutes(await table()).map((r) => routeKey(r.method, r.path)),
  );
  const stale = DERIVED_RBAC_ROUTE_RULES
    .filter((r) => !live.has(routeKey(r.method, r.path)))
    .map((r) => `${r.method} ${r.path}`);
  assertEquals(
    stale,
    [],
    `rbac_derived_route_rules.ts is stale — these generated rules no longer ` +
      `match a live route. Re-run:\n` +
      `  deno run --allow-read --allow-env scripts/rbac/rbac_inventory_report.ts\n` +
      stale.join("\n"),
  );
});

Deno.test("API-100: the derived half declares the gate the handler really enforces", async () => {
  // A generated rule is only worth anything if its `permission` came from the
  // route's own refusal. Re-probe and compare.
  const byKey = new Map(
    (await table()).map((r) => [routeKey(r.method, r.path), r]),
  );
  const wrong: string[] = [];
  for (const rule of DERIVED_RBAC_ROUTE_RULES) {
    const derived = byKey.get(routeKey(rule.method, rule.path));
    if (!derived) continue; // covered by the staleness test above
    const enforced = derived.requiredPermission ??
      derived.requiredAnyOf?.[0] ?? null;
    if (rule.permission !== enforced) {
      wrong.push(
        `${rule.method} ${rule.path}: declared ${rule.permission}, enforces ${enforced}`,
      );
    }
  }
  assertEquals(
    wrong,
    [],
    `a generated rule disagrees with the gate its route applies — regenerate:\n${
      wrong.join("\n")
    }`,
  );
});

Deno.test("the two halves stay distinguishable (curated rules are never marked derived)", () => {
  const mislabelled = CURATED_RBAC_ROUTE_RULES
    .filter((r) => r.derived === true)
    .map((r) => `${r.method} ${r.path}`);
  assertEquals(mislabelled, []);
  for (const rule of DERIVED_RBAC_ROUTE_RULES) {
    assertEquals(
      rule.derived,
      true,
      `${rule.method} ${rule.path} is in the generated file but not marked derived`,
    );
  }
  // The union really is a union.
  assert(
    RBAC_ROUTE_INVENTORY.length >= CURATED_RBAC_ROUTE_RULES.length,
    "the union dropped curated rules",
  );
});
