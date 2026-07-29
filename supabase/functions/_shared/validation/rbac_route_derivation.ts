// API-100 / API-101 / API-102 / API-103 / API-104 / OS-013 — the RBAC route
// table, DERIVED from the dispatcher instead of hand-maintained.
//
// ## Why this file exists
//
// `rbac_route_inventory.ts` was a hand-written data file with no code-derived
// source and no test comparing it to the routers, so **adding a route did not
// require touching it**. The RBAC suite then iterated that same file and called
// the pure function `requirePermission(claims, rule.permission)` — it never
// constructed a `Request`, never called `matchModuleRoute`, never invoked a
// handler. The two facts compose into the defect: *a route added with no gate
// passes the entire RBAC suite by simply not being listed.* That is how two
// attendance routes shipped unaudited.
//
// The fix is not to hand-edit the inventory until it happens to be right today.
// It is to make the route list a consequence of the code:
//
//   1. Build a CANDIDATE path set (below), then
//   2. ask the REAL dispatcher — `matchModuleRoute` — which `(method, path)`
//      pairs it actually claims. A router returns `null` for a path it does not
//      own and `405` for a method it does not serve; anything else means the
//      route exists. The routers answer, not a regex, so the method half of
//      every entry is exact.
//
// ## The candidate set, and why it has two sources
//
// Source extraction alone is NOT sufficient, and pretending otherwise is how a
// green suite coexists with an unlisted route. Measured against this codebase,
// text extraction misses two real dispatch shapes:
//
//   * object-literal route tables — `const routes: Record<string, RouteHandler> =
//     { "/transport/dashboard": handleDashboard, … }` (the whole transport,
//     library and widget-platform read surface), and
//   * multi-line `path.match(/^…$/)` calls, including every multi-parameter
//     route (`/admissions/leads/:id/followups/:followupId/complete`).
//
// 70 of the 73 rules that a source-only diff called "stale" were in fact LIVE
// routes the extractor could not see. Deleting them would have been exactly the
// wrong move. So the candidate set is the union of:
//
//   A. paths recovered from router source (`route_inventory.ts`, plus the two
//      extra shapes above), and
//   B. the paths the declared inventory already names.
//
// Union-then-verify is monotonic: (A) finds routes the inventory forgot, (B)
// covers dispatch shapes the text scanner cannot read, and the dispatcher
// adjudicates both. A route invisible to BOTH sources is the residual blind
// spot; `assertDerivationFloor` exists so that blind spot cannot silently grow.

import { walk } from "https://deno.land/std@0.224.0/fs/walk.ts";
import { dirname, fromFileUrl } from "https://deno.land/std@0.224.0/path/mod.ts";
import type { AppConfig } from "../config.ts";
import { matchModuleRoute, MODULE_ROUTES } from "../route_registry.ts";
import { extractRoutePaths, patternToPath, PROBE_ID } from "../route_inventory.ts";
import { signAccessToken } from "../jwt.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { handleRequest } from "../../api/app.ts";
import { RBAC_ROUTE_INVENTORY } from "./rbac_route_inventory.ts";

const SHARED_DIR = dirname(dirname(fromFileUrl(import.meta.url)));

/** Methods that CHANGE something — the set the completeness guard is about. */
export const MUTATING_METHODS = ["POST", "PUT", "PATCH", "DELETE"] as const;
export const ALL_METHODS = ["GET", ...MUTATING_METHODS] as const;

export const RBAC_PROBE_ID = PROBE_ID;

/** A `(method, path)` pair the real dispatcher claims, plus the gate it applies. */
export interface DerivedRoute {
  readonly method: string;
  /** Inventory form: parameters written as `:id`. */
  readonly path: string;
  /** Concrete form the dispatcher was asked about (parameters filled in). */
  readonly probePath: string;
  /** The `MODULE_ROUTES` entry whose declared prefix covers the path. */
  readonly module: string;
  /**
   * Status returned to an AUTHENTICATED caller holding **zero permissions**.
   * `403` means the route refuses a non-holder — the property the RBAC suite is
   * supposed to prove. Anything else means it did not.
   */
  readonly gateStatus: number;
  /** The permission named in the 403, when the gate is a single `requirePermission`. */
  readonly requiredPermission: string | null;
  /** The slugs named in the 403, when the gate is a `requireAnyPermission` OR-gate. */
  readonly requiredAnyOf: readonly string[] | null;
  /** The refusal message, for diagnosis when [gateStatus] is not 403. */
  readonly gateMessage: string;
}

/** Rule-form path (`/x/:id`) → concrete probe path (`/x/<uuid>`). */
export function toProbePath(rulePath: string): string {
  return rulePath.replace(/:[A-Za-z0-9_]+/g, RBAC_PROBE_ID);
}

/** Concrete probe path → rule-form path. */
export function toRulePath(probePath: string): string {
  return probePath.split(RBAC_PROBE_ID).join(":id");
}

/**
 * The `MODULE_ROUTES` entry that declares a prefix covering [path].
 *
 * Returns `""` when NO registered prefix covers it — which is OS-013 / API-104:
 * a path outside every declared prefix cannot be checked for double-ownership,
 * so the guarantee the registry exists to provide does not reach it.
 */
export function moduleForPath(path: string): string {
  let best = "";
  let bestLen = -1;
  for (const entry of MODULE_ROUTES) {
    for (const prefix of entry.prefixes) {
      const base = prefix.replace(/\/$/, "");
      const covered = path === base || path.startsWith(`${base}/`);
      if (covered && base.length > bestLen) {
        best = entry.name;
        bestLen = base.length;
      }
    }
  }
  return best;
}

// ── candidate path recovery ──────────────────────────────────────────────────

/** `"/transport/dashboard": handleDashboard` — object-literal route tables. */
const TABLE_KEY_RE = /"(\/[A-Za-z0-9._\-/]*)"\s*:/g;
/** `.match(/^…$/)`, tolerating the multi-line form the single-line regex misses. */
const MULTILINE_PATTERN_RE = /\.match\(\s*\/(\^[\s\S]{0,400}?\$)\/[a-z]*\s*,?\s*\)/g;

async function routerSources(): Promise<string[]> {
  const out: string[] = [];
  for await (const e of walk(SHARED_DIR, { exts: [".ts"], includeDirs: false })) {
    if (!e.name.includes("router") || e.name.endsWith("_test.ts")) continue;
    out.push(await Deno.readTextFile(e.path));
  }
  return out;
}

/** Paths recoverable from router source that `route_inventory.ts` cannot see. */
export async function extraRouterSourcePaths(): Promise<string[]> {
  const paths = new Set<string>();
  for (const src of await routerSources()) {
    for (const m of src.matchAll(TABLE_KEY_RE)) {
      const p = m[1]!;
      // A bare "/" or a content-type-ish key is not a route.
      if (p.length > 1 && !p.includes("//")) paths.add(p);
    }
    for (const m of src.matchAll(MULTILINE_PATTERN_RE)) {
      const p = patternToPath(m[1]!.replace(/\s+/g, ""));
      if (p) paths.add(p);
    }
  }
  return [...paths].sort();
}

/**
 * Every concrete path worth asking the dispatcher about: router source (both
 * extractors) ∪ the paths the declared inventory names.
 */
export async function candidateProbePaths(): Promise<string[]> {
  const paths = new Set<string>([
    ...await extractRoutePaths(),
    ...await extraRouterSourcePaths(),
    ...RBAC_ROUTE_INVENTORY.map((r) => toProbePath(r.path)),
  ]);
  return [...paths].sort();
}

// ── the derivation itself ────────────────────────────────────────────────────

const DERIVATION_SECRET = "test-jwt-secret-minimum-32-characters-long";
const derivationConfig = () => ({ jwtSecret: DERIVATION_SECRET } as AppConfig);

const ORG_SCOPE_MODULES = new Set([
  "director",
  "control_center",
  "organization_builder",
  "entitlements",
]);

/** The persona scope a path belongs to — parent/student routes gate on scope. */
export function scopeForPath(path: string, module: string): string {
  if (path.startsWith("/parent")) return "parent";
  if (path.startsWith("/student")) return "student";
  if (ORG_SCOPE_MODULES.has(module)) return "organization";
  return "school";
}

function zeroPermissionClaims(scope: string): AccessTokenClaims {
  return {
    sub: "a3000000-0000-4000-8000-000000000001",
    tenant_id: "a1000000-0000-4000-8000-000000000001",
    organization_id: "a1000000-0000-4000-8000-000000000001",
    school_id: "a2000000-0000-4000-8000-000000000001",
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: [],
    permissions_version: 1,
    scope,
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "rbac-derivation",
  } as AccessTokenClaims;
}

const SINGLE_PERMISSION_RE = /Permission required:\s*([A-Za-z0-9_]+)\s*$/;
const ANY_PERMISSION_RE = /Permission required:\s*one of\s*([A-Za-z0-9_,\s]+)$/;

/**
 * Derives the live route table AND the gate each route applies, in one pass.
 *
 * Two probes per candidate `(method, path)`:
 *
 *   1. `matchModuleRoute` with an ANONYMOUS request — does any router CLAIM this
 *      pair? A router returns `null` when it does not own the path.
 *   2. `handleRequest` with a valid token carrying **zero permissions** — what
 *      does the route do to an authenticated non-holder? `403` is the answer the
 *      RBAC suite is supposed to be proving; `405` means the path exists but the
 *      method does not, so it is not a route and is dropped.
 *
 * Nothing is written anywhere: no database is configured in the test
 * environment, so any handler that gets past its gate stops at a 503 before it
 * can touch data. That 503 is itself the signal — it means the request reached
 * the database WITHOUT being refused.
 */
export async function deriveRouteTable(): Promise<DerivedRoute[]> {
  const config = derivationConfig();
  const paths = await candidateProbePaths();
  const table: DerivedRoute[] = [];
  const tokens = new Map<string, string>();
  const realLog = console.log;
  console.log = () => {};
  try {
    for (const probePath of paths) {
      const module = moduleForPath(probePath);
      const scope = scopeForPath(probePath, module);
      if (!tokens.has(scope)) {
        tokens.set(
          scope,
          await signAccessToken(DERIVATION_SECRET, zeroPermissionClaims(scope), 900),
        );
      }
      const token = tokens.get(scope)!;

      for (const method of ALL_METHODS) {
        const body = method === "GET" ? undefined : "{}";
        let claimed: Response | null;
        try {
          claimed = await matchModuleRoute(
            new Request(`https://x${probePath}`, {
              method,
              headers: { "content-type": "application/json" },
              body,
            }),
            config,
            method,
            probePath,
          );
        } catch {
          // A router that throws still CLAIMED the path — keep it so the guard
          // reports it rather than losing it.
          claimed = new Response(null, { status: 599 });
        }
        if (claimed === null) continue; // no router owns this (method, path)

        let gateStatus = 599;
        let gateMessage = "";
        try {
          const res = await handleRequest(
            new Request(`https://x${probePath}`, {
              method,
              headers: {
                authorization: `Bearer ${token}`,
                "content-type": "application/json",
              },
              body,
            }),
            // `handleRequest` takes a config FACTORY; `matchModuleRoute` takes the
            // resolved object. Passing the object here silently fails JWT
            // verification and turns every probe into a 500, which would make the
            // gate report look catastrophic and prove nothing.
            derivationConfig,
          );
          gateStatus = res.status;
          try {
            gateMessage = (await res.json())?.error?.message ?? "";
          } catch { /* non-JSON body */ }
        } catch (e) {
          gateMessage = `THREW ${(e as Error).message.slice(0, 120)}`;
        }
        // 405 = the path is real but this method is not a route on it.
        if (gateStatus === 405) continue;

        const anyMatch = gateMessage.match(ANY_PERMISSION_RE);
        const singleMatch = gateMessage.match(SINGLE_PERMISSION_RE);
        table.push({
          method,
          path: toRulePath(probePath),
          probePath,
          module,
          gateStatus,
          requiredPermission: anyMatch ? null : (singleMatch?.[1] ?? null),
          requiredAnyOf: anyMatch
            ? anyMatch[1]!.split(",").map((s) => s.trim()).filter(Boolean)
            : null,
          gateMessage,
        });
      }
    }
  } finally {
    console.log = realLog;
  }
  return table;
}

/** The mutating subset — the surface the completeness guard is about. */
export function mutatingRoutes(table: readonly DerivedRoute[]): DerivedRoute[] {
  const mutating = new Set<string>(MUTATING_METHODS);
  return table.filter((r) => mutating.has(r.method));
}

export function routeKey(method: string, path: string): string {
  return `${method} ${toProbePath(path)}`;
}

/**
 * Coverage floor. The whole failure mode of a source-scanning guard is that the
 * scan silently stops matching and the suite proves nothing while staying green
 * — so the derivation asserts its own size before anything is concluded from it.
 */
export function assertDerivationFloor(table: readonly DerivedRoute[]): void {
  const mutating = mutatingRoutes(table).length;
  if (table.length < 550 || mutating < 280) {
    throw new Error(
      `RBAC route derivation collapsed: ${table.length} routes ` +
        `(${mutating} mutating). Expected >= 550 / >= 280. Until this is fixed, ` +
        `every guard built on the derivation proves nothing.`,
    );
  }
}
