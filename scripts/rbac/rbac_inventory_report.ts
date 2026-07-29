#!/usr/bin/env -S deno run --allow-read --allow-env
// API-100 / API-102 — the RBAC inventory GENERATOR + reconciliation report.
//
// Run it whenever you add, move or delete a route:
//
//   deno run --allow-read --allow-env scripts/rbac/rbac_inventory_report.ts
//
// It derives the live route table from the dispatcher
// (`_shared/validation/rbac_route_derivation.ts`), diffs it against
// `_shared/validation/rbac_route_inventory.ts` in BOTH directions, and prints a
// paste-ready rule for every mutating route the inventory is missing — with the
// permission the handler ACTUALLY enforces, read out of the 403 the dispatcher
// returns to a caller holding zero permissions.
//
// The rules it prints are therefore derived from enforcement, not guessed from a
// route name. Paste them into `rbac_derived_route_rules.ts`; do not hand-author
// them. The paired guard (`rbac_generated_inventory_test.ts`) fails the build
// whenever the diff is non-zero, so a route added without running this cannot
// ship.
//
// `--json` prints the raw report instead of the paste-ready block.

import {
  deriveRouteTable,
  type DerivedRoute,
  mutatingRoutes,
  routeKey,
  scopeForPath,
} from "../../supabase/functions/_shared/validation/rbac_route_derivation.ts";
import { RBAC_ROUTE_INVENTORY } from "../../supabase/functions/_shared/validation/rbac_route_inventory.ts";

function ruleLine(route: DerivedRoute): string {
  const permission = route.requiredPermission
    ? `"${route.requiredPermission}"`
    : route.requiredAnyOf
    ? `"${route.requiredAnyOf[0]}"`
    : "null";
  const note = route.requiredPermission
    ? ""
    : route.requiredAnyOf
    ? ` // OR-gate: ${route.requiredAnyOf.join(" | ")}`
    : ` // ungated at dispatch: ${route.gateStatus} ${route.gateMessage.slice(0, 70)}`;
  return `  { method: "${route.method}", path: "${route.path}", permission: ${permission}, ` +
    `scope: "${scopeForPath(route.path, route.module)}", module: "${route.module || "(unregistered)"}", derived: true },${note}`;
}

if (import.meta.main) {
  const table = await deriveRouteTable();
  const mutating = mutatingRoutes(table);
  const derivedKeys = new Set(table.map((r) => routeKey(r.method, r.path)));
  const inventoryKeys = new Set(
    RBAC_ROUTE_INVENTORY.map((r) => routeKey(r.method, r.path)),
  );

  const missing = mutating.filter((r) => !inventoryKeys.has(routeKey(r.method, r.path)));
  const dead = RBAC_ROUTE_INVENTORY.filter(
    (r) => !derivedKeys.has(routeKey(r.method, r.path)),
  );
  const unregistered = [
    ...new Set(table.filter((r) => r.module === "").map((r) => r.path)),
  ];
  const ungated = mutating.filter((r) => r.gateStatus !== 403);
  const ungatedReads = table.filter(
    (r) => r.method === "GET" && r.gateStatus !== 403,
  );

  if (Deno.args.includes("--json")) {
    console.log(
      JSON.stringify({ table, missing, dead, unregistered, ungated }, null, 2),
    );
    Deno.exit(0);
  }

  console.log(`# derived routes:              ${table.length}`);
  console.log(`# mutating:                    ${mutating.length}`);
  console.log(`# missing from inventory:      ${missing.length}`);
  console.log(`# rules without routes:        ${dead.length}`);
  console.log(`# outside declared prefixes:   ${unregistered.length}`);
  console.log(`# mutating, NOT 403 at dispatch: ${ungated.length}`);
  console.log(`# reads,    NOT 403 at dispatch: ${ungatedReads.length}`);
  console.log("");

  if (dead.length) {
    console.log("## Rules to DELETE (no live route answers them)");
    for (const r of dead) console.log(`  ${r.method} ${r.path}  [${r.module}]`);
    console.log("");
  }
  if (unregistered.length) {
    console.log("## Paths outside every MODULE_ROUTES prefix (OS-013 / API-104)");
    for (const p of unregistered) console.log(`  ${p}`);
    console.log("");
  }
  if (ungated.length) {
    console.log("## MUTATING routes that do NOT refuse a zero-permission caller");
    for (const r of ungated) {
      console.log(
        `  ${r.method} ${r.path} -> ${r.gateStatus} ${r.gateMessage.slice(0, 80)}`,
      );
    }
    console.log("");
  }
  if (missing.length) {
    console.log("## Paste into DERIVED_RBAC_ROUTE_RULES");
    const byModule = new Map<string, DerivedRoute[]>();
    for (const r of missing) {
      const k = r.module || "(unregistered)";
      if (!byModule.has(k)) byModule.set(k, []);
      byModule.get(k)!.push(r);
    }
    for (const [module, rows] of [...byModule].sort()) {
      console.log(`  // ── ${module} ──`);
      for (const r of rows) console.log(ruleLine(r));
    }
  }
}
