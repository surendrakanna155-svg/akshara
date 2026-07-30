// ICA-F4 — guard for the declarative module-route registry.
//
// Locks the two F4 invariants:
//   1. FLIP-LOCK (static): no module router emits its own route-level 404. The SINGLE
//      source of "Route not found" is app.ts's central dispatcher. A future edit that
//      re-introduces a greedy `errorEnvelope("NOT_FOUND", ...404)` in a router fails here.
//   2. SINGLE-OWNERSHIP (behavioral): for every representative real path — especially the
//      cross-prefix overlaps (/finance vs /finance/inventory-reconciliation, /inventory vs
//      /inventory/distribution, /academic vs /academic/timetables, /parent|/teacher|/student
//      vs communication/pilot) — exactly ONE registry entry claims it, and it is the EXPECTED
//      one. Disjoint ownership is what makes the iteration order non-load-bearing.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { walk } from "https://deno.land/std@0.224.0/fs/walk.ts";
import { dirname, fromFileUrl } from "https://deno.land/std@0.224.0/path/mod.ts";
import type { AppConfig } from "./config.ts";
import { MODULE_ROUTES } from "./route_registry.ts";

const config = { jwtSecret: "test-jwt-secret-minimum-32-characters-long" } as AppConfig;
const SHARED_DIR = dirname(fromFileUrl(import.meta.url));

const GREEDY_404 = 'errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404)';

function req(method: string, path: string): Request {
  return new Request(`https://x${path}`, {
    method,
    headers: { "content-type": "application/json" },
    body: method === "GET" ? undefined : "{}",
  });
}

// Which registry entries claim (method, path). null ⇒ not claimed. Any non-null Response ⇒ claimed.
async function owners(method: string, path: string): Promise<string[]> {
  const claimed: string[] = [];
  for (const entry of MODULE_ROUTES) {
    const res = await entry.route(req(method, path), config, method, path);
    if (res !== null) claimed.push(entry.name);
  }
  return claimed;
}

Deno.test("F4 flip-lock: no module router emits its own route-level 404", async () => {
  const offenders: string[] = [];
  for await (
    const e of walk(SHARED_DIR, { exts: [".ts"], includeDirs: false })
  ) {
    if (!e.name.includes("router") || e.name.endsWith("_test.ts")) continue;
    const src = await Deno.readTextFile(e.path);
    if (src.includes(GREEDY_404)) {
      const n = src.split(GREEDY_404).length - 1;
      offenders.push(`${e.path.replace(SHARED_DIR, "_shared")} (${n})`);
    }
  }
  assertEquals(
    offenders,
    [],
    `Module routers must return null (not a route-404) on no-match; the central 404 lives in app.ts. Offenders:\n${offenders.join("\n")}`,
  );
});

Deno.test("F4 registry shape: names unique, prefixes+route present", () => {
  assert(MODULE_ROUTES.length >= 60, `expected the full module registry, got ${MODULE_ROUTES.length}`);
  const names = new Set<string>();
  for (const entry of MODULE_ROUTES) {
    assert(entry.name.length > 0, "entry missing name");
    assert(!names.has(entry.name), `duplicate registry name: ${entry.name}`);
    names.add(entry.name);
    assert(entry.prefixes.length > 0, `entry ${entry.name} declares no prefixes`);
    for (const p of entry.prefixes) assert(p.startsWith("/"), `entry ${entry.name} prefix ${p} must start with /`);
    assertEquals(typeof entry.route, "function", `entry ${entry.name} has no route fn`);
  }
});

// (method, path, expectedOwner) — chosen to STRESS the cross-prefix overlaps. Each must be
// claimed by EXACTLY ONE registry entry, and that entry must be `expectedOwner`.
const OWNERSHIP: ReadonlyArray<readonly [string, string, string]> = [
  // finance vs inventory_finance (both under /finance)
  ["GET", "/finance/dashboard", "finance"],
  ["GET", "/finance/inventory-reconciliation/dashboard", "inventory_finance"],
  // inventory vs inventory_distribution vs inventory_finance (all under /inventory)
  ["GET", "/inventory/assets", "inventory"],
  ["GET", "/inventory/distribution/dashboard", "inventory_distribution"],
  ["GET", "/inventory/vendors/catalog", "inventory_finance"],
  // academic vs timetable (both under /academic) vs exam_administration (/academics)
  ["GET", "/academic/years", "academic"],
  ["GET", "/academic/timetables/summary", "timetable"],
  ["GET", "/academics/exams", "exam_administration"],
  // communication vs the generic persona routers (cross-prefix)
  ["GET", "/parent/notifications", "communication"],
  ["GET", "/parent/messages/threads", "communication"],
  ["GET", "/student/notifications", "communication"],
  ["GET", "/teacher/messages", "communication"],
  // pilot_operations vs the generic persona routers (cross-prefix)
  ["POST", "/parent/leave", "pilot_operations"],
  ["POST", "/student/homework/submit", "pilot_operations"],
  // PRA-P0-12: the governed exam-mark route is the teacher router's, NOT pilot's
  ["PUT", "/teacher/exams/marks/00000000-0000-4000-8000-000000000001", "teacher"],
  // platform namespace: org_builder vs entitlements
  ["GET", "/platform/org-builder/packs", "organization_builder"],
  ["GET", "/platform/subscriptions", "entitlements"],
  // /school/* (completion) vs /school-config (config) — hyphen, not a subtree
  ["GET", "/school/branding", "school_completion"],
  ["GET", "/school-config", "school_config"],
  // a spread of clean single-prefix modules
  ["GET", "/sis/students", "sis"],
  ["GET", "/admissions/leads", "admissions"],
  ["GET", "/hr/dashboard", "hr"],
  ["GET", "/transport/routes", "transport"],
  ["GET", "/support/incidents", "support"],
  ["GET", "/identity/roles", "identity"],
  ["GET", "/audit/events", "audit"],
  ["GET", "/search", "search"],
  ["POST", "/payments/intents/initiate", "payment"],
];

Deno.test("F4 single-ownership: each representative path has exactly one owner (the expected one)", async () => {
  const problems: string[] = [];
  for (const [method, path, expected] of OWNERSHIP) {
    const claimed = await owners(method, path);
    if (claimed.length !== 1) {
      problems.push(`${method} ${path}: expected 1 owner (${expected}), got [${claimed.join(", ")}]`);
    } else if (claimed[0] !== expected) {
      problems.push(`${method} ${path}: expected owner ${expected}, got ${claimed[0]}`);
    }
  }
  assertEquals(problems, [], `route ownership drift:\n${problems.join("\n")}`);
});

Deno.test("F4 central-404: an unmatched path is owned by no module router", async () => {
  assertEquals(await owners("GET", "/definitely-not-a-real-route-zzz"), []);
  assertEquals(await owners("GET", "/finance/__no_such_finance_route__"), []);
  assertEquals(await owners("POST", "/parent/__no_such_parent_route__"), []);
});
