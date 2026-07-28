// QW6 · QA-X-017 — server-side denied-access audit.
//
// Phase-prior reality (discovery): `requirePermission` / `requireAnyPermission`
// returned a 403 with NO audit trail, so a blocked mutation left no
// security-observability record on the server. This wires an `access_denied`
// event at the single request choke point (`handleRequest`) and proves it
// emits on a REAL RBAC deny — and stays silent on allow / non-403 — all DB-free
// via the app.ts seam.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleRequest } from "./app.ts";
import {
  type AccessDeniedEvent,
  parseRequiredPermission,
} from "../_shared/audit/access_denied_audit.ts";
import type { AppConfig } from "../_shared/config.ts";
import type { AccessTokenClaims } from "../_shared/jwt.ts";
import { signAccessToken } from "../_shared/jwt.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const goodConfig = () => ({ jwtSecret: SECRET } as AppConfig);

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "user-1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "schoolAdmin", role_slugs: ["schoolAdmin"], primary_role: "schoolAdmin",
    permissions: perms, permissions_version: 1, scope: "school", school_group_id: null,
    student_id: null, child_ids: [], session_id: "s1", ...over,
  };
}

async function tokenReq(
  method: string, path: string, perms: string[], body?: unknown,
  over: Partial<AccessTokenClaims> = {},
): Promise<Request> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  return new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

/** Capturing sink so emission is asserted deterministically (no DB / no logs). */
function capturingSink() {
  const events: AccessDeniedEvent[] = [];
  return { events, sink: (e: AccessDeniedEvent) => { events.push(e); } };
}

// ── the deny path emits an audit event with the real actor + permission ──────
Deno.test("QA-X-017: a 403 RBAC deny emits an access_denied audit event", async () => {
  const { events, sink } = capturingSink();
  // POST /finance/collections requires manageFinance; this token lacks it → 403
  // BEFORE any DB work (so this is DB-free).
  const req = await tokenReq("POST", "/finance/collections", [],
    { invoice_id: "inv-1", amount_collected: 5000, payment_method: "cash" });

  const res = await handleRequest(req, goodConfig, sink);

  assertEquals(res.status, 403);
  assertEquals(events.length, 1);
  const e = events[0];
  assertEquals(e.type, "access_denied");
  assertEquals(e.status, 403);
  assertEquals(e.method, "POST");
  assertEquals(e.path, "/finance/collections");
  // Actor recovered from the (valid) token, not "unknown".
  assertEquals(e.actorId, "user-1");
  assertEquals(e.tenantId, "org-1");
  assertEquals(e.schoolId, "school-1");
  assertEquals(e.requiredPermission, "manageFinance");
  assertEquals(typeof e.correlationId === "string" && e.correlationId.length > 0, true);
});

// ── an authorized request does NOT emit a denial ─────────────────────────────
Deno.test("QA-X-017: an authorized request (passes the gate) emits no denial", async () => {
  const { events, sink } = capturingSink();
  // With manageFinance the gate passes and the request reaches the (unconfigured)
  // DB → 503, NOT a 403 — so nothing is audited as a denial.
  const req = await tokenReq("POST", "/finance/collections", ["manageFinance"],
    { invoice_id: "inv-1", amount_collected: 5000, payment_method: "cash" });

  const res = await handleRequest(req, goodConfig, sink);

  assertEquals(res.status, 503);
  assertEquals(events.length, 0);
});

// ── a 404 / non-403 is not a denial ──────────────────────────────────────────
Deno.test("QA-X-017: a 404 (non-403) emits no access_denied event", async () => {
  const { events, sink } = capturingSink();
  // ICA-F1: authenticate so the probe passes the central auth gate and reaches the
  // 404 fallback (an unauthenticated probe would 401 before dispatch). Only a 403
  // records an access_denied event; a 404 must not.
  const res = await handleRequest(
    await tokenReq("POST", "/does/not/exist", []),
    goodConfig,
    sink,
  );
  assertEquals(res.status, 404);
  assertEquals(events.length, 0);
});

// ── reading the audit body does not consume the client response ──────────────
Deno.test("QA-X-017: the 403 envelope returned to the client is intact after auditing", async () => {
  const { sink } = capturingSink();
  const req = await tokenReq("POST", "/finance/collections", []);
  const res = await handleRequest(req, goodConfig, sink);
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.data, null);
  assertEquals(env.error.code, "FORBIDDEN");
});

// ── the permission parser handles single + OR messages ───────────────────────
Deno.test("QA-X-017: parseRequiredPermission handles single and OR-gate messages", () => {
  assertEquals(parseRequiredPermission("Permission required: manageFinance"), "manageFinance");
  assertEquals(
    parseRequiredPermission("Permission required: one of manageFinance, viewFinance"),
    "manageFinance, viewFinance",
  );
  assertEquals(parseRequiredPermission("Some other 403 reason"), null);
  assertEquals(parseRequiredPermission(undefined), null);
});
