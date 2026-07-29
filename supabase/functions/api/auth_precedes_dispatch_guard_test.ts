// SEC-AUTH-FIRST — the guard: NOTHING outside the declared allow-list answers an
// anonymous request with anything other than 401.
//
// WHY A SECOND FORCED-AUTH TEST EXISTS
// `eng4_5_forced_auth_test.ts` already claimed this invariant, and it passed while
// the live pilot answered anonymous callers with `422 classLabel is required`
// (`/attendance/register/monthly`) and `404 Route not found` (`/audit/events`,
// `/identity/roles`). It passed because it probes TWELVE hand-picked paths, and
// every one of those twelve happens to be served by a handler that authenticates
// before it validates. It could not see the routes that did not — because it never
// asked them. A sample cannot prove a universal.
//
// So this guard does not sample. It recovers the route surface from the router
// sources (`_shared/route_inventory.ts`) and probes ALL of it, plus a synthetic
// unknown path under every prefix the registry declares, and it fails on the FULL
// list of offenders rather than the first — a security guard should tell you the
// whole blast radius in one run.
//
// The three things it locks:
//   1. EVERY known route × every method → 401 anonymous (no 422: no parameter
//      contract is disclosed; no 403/405: no existence or method disclosure).
//   2. UNKNOWN paths → 401 too, so 404-vs-401 cannot be diffed to map the API.
//   3. The allow-list is exactly as declared, and every entry on it really is
//      reachable (an entry that no longer bypasses the gate is dead weight that
//      makes the list lie).
//
// Coverage floors are asserted so that if the source extraction ever stops
// matching, this test fails loudly instead of silently proving nothing — the
// failure mode that let the original test pass over a live exposure.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleRequest } from "./app.ts";
import type { AppConfig } from "../_shared/config.ts";
import { PUBLIC_ROUTES } from "../_shared/public_routes.ts";
import { MODULE_ROUTES } from "../_shared/route_registry.ts";
import {
  extractModuleRoutePaths,
  extractRoutePaths,
  extractTopLevelRoutePaths,
} from "../_shared/route_inventory.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";

/** The production posture: APP_ENV=production, no internal health token configured. */
const prodConfig = () =>
  ({ jwtSecret: SECRET, environment: "production" } as AppConfig);

/** Methods an anonymous caller can send. OPTIONS is excluded: a CORS preflight
 * carries no credentials by definition and returns no data. */
const METHODS = ["GET", "POST", "PUT", "PATCH", "DELETE"] as const;

/** The gate's own rejection — the exact response an anonymous caller must get. */
const GATE_STATUS = 401;
const GATE_CODE = "UNAUTHORIZED";
const GATE_MESSAGE = "Missing bearer token";

function anonReq(method: string, path: string): Request {
  return new Request(`https://x${path}`, {
    method,
    headers: { "content-type": "application/json" },
    body: method === "GET" || method === "DELETE" ? undefined : "{}",
  });
}

/** Runs `fn` with request logging silenced — this suite makes thousands of calls. */
async function quietly<T>(fn: () => Promise<T>): Promise<T> {
  const real = console.log;
  console.log = () => {};
  try {
    return await fn();
  } finally {
    console.log = real;
  }
}

function isAllowListed(method: string, path: string): boolean {
  return PUBLIC_ROUTES.some((e) =>
    e.match.kind === "prefix"
      ? path === e.match.path.replace(/\/$/, "") || path.startsWith(e.match.path)
      : e.match.method === method && e.match.path === path
  );
}

/** Probes (method, path) anonymously; returns a describing string, or null when correctly gated. */
async function offence(method: string, path: string): Promise<string | null> {
  let res: Response;
  try {
    res = await handleRequest(anonReq(method, path), prodConfig);
  } catch (e) {
    return `${method} ${path} -> THREW ${(e as Error).message.slice(0, 100)}`;
  }
  if (res.status === GATE_STATUS) return null;
  let body = "";
  try {
    body = JSON.stringify(await res.json());
  } catch { /* non-JSON body */ }
  return `${method} ${path} -> ${res.status} ${body.slice(0, 140)}`;
}

// ── 1. Coverage floors — the extraction must not silently degrade ────────────

Deno.test("SEC-AUTH-FIRST guard: the route inventory is complete enough to prove anything", async () => {
  const moduleRoutes = await extractModuleRoutePaths();
  const topLevel = await extractTopLevelRoutePaths();
  // Today: ~559 module route paths and ~15 top-level paths. The floors are set
  // well below that so ordinary route churn does not trip them, while a regex
  // that stops matching (the way this whole class of test fails silently) does.
  assert(
    moduleRoutes.length >= 450,
    `route extraction collapsed: only ${moduleRoutes.length} module routes found (expected >= 450). ` +
      `This test proves nothing until it is fixed.`,
  );
  assert(
    topLevel.length >= 12,
    `top-level route extraction collapsed: only ${topLevel.length} found (expected >= 12).`,
  );
  // Spot-check that the three routes the live pilot actually leaked are in scope.
  for (const p of ["/attendance/register/monthly", "/audit/events", "/identity/roles"]) {
    assert(moduleRoutes.includes(p), `${p} is missing from the extracted inventory`);
  }
});

// ── 2. THE GUARD — every known route, every method, anonymous → 401 ──────────

Deno.test("SEC-AUTH-FIRST guard: no route answers an anonymous request with anything but 401", async () => {
  const paths = await extractRoutePaths();
  const offenders = await quietly(async () => {
    const found: string[] = [];
    for (const path of paths) {
      for (const method of METHODS) {
        if (isAllowListed(method, path)) continue;
        const o = await offence(method, path);
        if (o) found.push(o);
      }
    }
    return found;
  });
  assertEquals(
    offenders,
    [],
    `Authentication must precede validation AND dispatch. These routes answered an ` +
      `unauthenticated caller with something other than 401 — a 422 discloses the ` +
      `route's parameter contract, a 404/405 discloses that the route exists:\n` +
      offenders.join("\n"),
  );
});

// ── 3. Route-existence non-disclosure — unknown paths are 401 too ────────────

Deno.test("SEC-AUTH-FIRST guard: an anonymous caller cannot tell a real route from a fake one", async () => {
  const offenders = await quietly(async () => {
    const found: string[] = [];
    for (const entry of MODULE_ROUTES) {
      for (const prefix of entry.prefixes) {
        const base = prefix.replace(/\/$/, "");
        for (const path of [base, `${base}/__sec_auth_first_probe__`]) {
          for (const method of ["GET", "POST"]) {
            // The webhook namespace is public by design, so within it a caller CAN
            // tell a real callback (403 bad signature) from a fake one (404). That
            // residual disclosure is accepted and bounded: a payment gateway must
            // be able to reach the endpoint without a session, and "this API
            // receives Razorpay callbacks" is not a secret. It is confined to the
            // allow-listed prefixes — everywhere else the 401 is uniform.
            if (isAllowListed(method, path)) continue;
            const o = await offence(method, path);
            if (o) found.push(`[${entry.name}] ${o}`);
          }
        }
      }
    }
    // Paths that belong to no module at all must be indistinguishable from real ones.
    for (const path of ["/definitely/not/a/route", "/zzz", "/audit/events/__nope__"]) {
      const o = await offence("GET", path);
      if (o) found.push(`[unregistered] ${o}`);
    }
    return found;
  });
  assertEquals(
    offenders,
    [],
    `404-vs-401 lets an anonymous caller map the API by diffing status codes. ` +
      `These probes did not return 401:\n${offenders.join("\n")}`,
  );
});

// ── 4. The exact regressions confirmed on the live pilot ────────────────────

Deno.test("SEC-AUTH-FIRST guard: the three live-confirmed leaks are closed, and it is the GATE that closes them", async () => {
  // Asserting the body, not just the status: a 401 produced by a handler's own
  // check would still mean the request reached the handler. "Missing bearer token"
  // is the central gate's message, so this pins WHERE the request stopped.
  const cases: ReadonlyArray<readonly [string, string]> = [
    ["GET", "/attendance/register/monthly"], // live: 422 "classLabel is required"
    ["GET", "/attendance/register"], //         same handler family
    ["GET", "/attendance/pending"], //          same handler family
    ["GET", "/audit/events"], //                live: 404 "Route not found"
    ["GET", "/identity/roles"], //              live: 404 "Route not found"
  ];
  for (const [method, path] of cases) {
    const res = await quietly(() => handleRequest(anonReq(method, path), prodConfig));
    assertEquals(res.status, GATE_STATUS, `${method} ${path}`);
    const body = await res.json();
    assertEquals(body.error.code, GATE_CODE, `${method} ${path}`);
    assertEquals(
      body.error.message,
      GATE_MESSAGE,
      `${method} ${path} was rejected somewhere other than the central gate — the ` +
        `request reached a handler before it was authenticated`,
    );
  }
});

// ── 5. The allow-list is exactly as declared, and every entry is honest ─────

Deno.test("SEC-AUTH-FIRST guard: the public allow-list is exactly the declared set", () => {
  // A snapshot, so widening the unauthenticated surface cannot happen quietly:
  // adding an entry fails this test until the new line is added here too.
  const declared = PUBLIC_ROUTES.map((e) =>
    e.match.kind === "prefix" ? `PREFIX ${e.match.path}` : `${e.match.method} ${e.match.path}`
  ).sort();
  assertEquals(declared, [
    "GET /health",
    "GET /health/backup",
    "GET /health/operations",
    "GET /health/providers",
    "GET /health/ready",
    "GET /health/storage",
    "GET /health/tenant-access",
    "POST /auth/login",
    "POST /auth/refresh",
    "POST /auth/verify-otp",
    "POST /communications/delivery/webhook",
    "PREFIX /webhooks/",
  ]);
  // Every entry must justify itself — an allow-list without reasons rots.
  for (const e of PUBLIC_ROUTES) {
    assert(e.guardedBy.length > 10, `allow-list entry ${JSON.stringify(e.match)} has no guardedBy`);
    assert(e.reason.length > 10, `allow-list entry ${JSON.stringify(e.match)} has no reason`);
  }
});

Deno.test("SEC-AUTH-FIRST guard: every allow-listed route really does bypass the gate", async () => {
  const notReached: string[] = [];
  await quietly(async () => {
    for (const e of PUBLIC_ROUTES) {
      const method = e.match.kind === "prefix" ? "POST" : e.match.method;
      const path = e.match.kind === "prefix" ? `${e.match.path}razorpay` : e.match.path;
      const res = await handleRequest(anonReq(method, path), prodConfig);
      let message = "";
      try {
        message = (await res.json())?.error?.message ?? "";
      } catch { /* non-JSON */ }
      // The precise guarantee: the response is NOT the gate's rejection, i.e. the
      // request got past the gate to whatever really authenticates the route.
      if (res.status === GATE_STATUS && message === GATE_MESSAGE) {
        notReached.push(`${method} ${path} is allow-listed but was blocked by the central gate`);
      }
    }
  });
  assertEquals(notReached, [], notReached.join("\n"));
});

Deno.test("SEC-AUTH-FIRST guard: the sensitive /health/* probes are allow-listed but NOT open (403 in production)", async () => {
  // They bypass the SESSION gate because operators probe them with an internal
  // token, not a login. That is only acceptable while their own guard holds — so
  // it is asserted here, on the same production posture the deployment runs
  // (deploy/akshara-vps/verify-deployment-security.sh check [1]).
  for (
    const path of [
      "/health/tenant-access",
      "/health/operations",
      "/health/storage",
      "/health/providers",
      "/health/backup",
    ]
  ) {
    const res = await quietly(() => handleRequest(anonReq("GET", path), prodConfig));
    assertEquals(res.status, 403, `${path} must be 403 to an anonymous caller in production`);
    assertEquals((await res.json()).error.code, "FORBIDDEN", path);
  }
});

Deno.test("SEC-AUTH-FIRST guard: liveness and readiness stay open and disclose nothing", async () => {
  const live = await quietly(() => handleRequest(anonReq("GET", "/health"), prodConfig));
  assertEquals(live.status, 200);
  const liveBody = await live.text();
  // Mirrors verify-deployment-security.sh check [2].
  for (const leak of ["bypassRls", "bucket", "lastBackup", "isolation", "erp_tenant"]) {
    assertEquals(liveBody.includes(leak), false, `/health leaked ${leak}: ${liveBody}`);
  }
  const ready = await quietly(() => handleRequest(anonReq("GET", "/health/ready"), prodConfig));
  assertEquals(
    ready.status === GATE_STATUS,
    false,
    "/health/ready must stay reachable — the watchdog probes it",
  );
});

// ── 6. Session-bearing /auth/* routes are NOT public ────────────────────────

Deno.test("SEC-AUTH-FIRST guard: /auth/* routes that carry a session are gated like everything else", async () => {
  const offenders = await quietly(async () => {
    const found: string[] = [];
    for (
      const [method, path] of [
        ["GET", "/auth/me"],
        ["GET", "/auth/permissions"],
        ["POST", "/auth/logout"],
        ["POST", "/auth/sessions/logout-all"],
        ["POST", "/auth/sessions/revoke"],
        ["POST", "/auth/context/switch"],
      ] as const
    ) {
      const o = await offence(method, path);
      if (o) found.push(o);
    }
    return found;
  });
  assertEquals(offenders, [], `session-bearing /auth/* must be 401 anonymous:\n${offenders.join("\n")}`);
});
