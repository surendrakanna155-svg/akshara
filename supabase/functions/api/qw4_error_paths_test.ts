// QW4 · QA-B-062/063/064/067/068/069 — index-level error envelope + CORS +
// correlation-id contract, tested against the server-free `handleRequest` seam
// (app.ts) so no socket / --allow-net is needed.
//
// 503 TENANT_DB_NOT_CONFIGURED here means a handler passed auth+gate and reached
// the (unconfigured) tenant DB — the DB-free "authorized" proxy used throughout QW4.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleRequest } from "./app.ts";
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
  over: Partial<AccessTokenClaims> = {}, headers: Record<string, string> = {},
): Promise<Request> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  return new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

// ── QA-B-062 — global 404 fallthrough ───────────────────────────────────────
// ICA-F1: the central auth chokepoint authenticates BEFORE the 404 fallback, so an
// UNAUTHENTICATED probe of an unknown route now 401s (auth-first; unauthenticated
// callers cannot enumerate route existence). These probes are AUTHENTICATED so they
// pass the gate and still exercise the 404 registry-fallthrough they are guarding.
Deno.test("QA-B-062: an unregistered route falls through to a 404 NOT_FOUND envelope", async () => {
  const res = await handleRequest(await tokenReq("POST", "/does/not/exist", []), goodConfig);
  assertEquals(res.status, 404);
  const env = await res.json();
  assertEquals(env.data, null);
  assertEquals(env.error.code, "NOT_FOUND");
});

Deno.test("QA-B-062: an unknown method on a known prefix also 404s (no accidental match)", async () => {
  const res = await handleRequest(await tokenReq("DELETE", "/finance/collections", []), goodConfig);
  assertEquals(res.status, 404);
  assertEquals((await res.json()).error.code, "NOT_FOUND");
});

// ── QA-B-064 — CONFIG_ERROR(500) when config fails to load ───────────────────
Deno.test("QA-B-064: a failing config loader yields a 500 CONFIG_ERROR envelope", async () => {
  const res = await handleRequest(
    new Request("https://x/health"),
    () => { throw new Error("SUPABASE_URL missing"); },
  );
  assertEquals(res.status, 500);
  const env = await res.json();
  assertEquals(env.error.code, "CONFIG_ERROR");
  // ENG-7 (SEC-6): the client gets a GENERIC message — the real reason
  // ("SUPABASE_URL missing") is logged server-side only, never leaked.
  assertEquals(env.error.message, "Server configuration error.");
  assertEquals(env.error.message.includes("SUPABASE_URL"), false);
  // QA-B-068/069 — the CONFIG_ERROR path is also decorated with CORS + correlation id.
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
  assertEquals((res.headers.get("x-correlation-id") ?? "").length > 0, true);
});

// ── QA-B-068 — CORS ──────────────────────────────────────────────────────────
Deno.test("QA-B-068: OPTIONS preflight returns 200 ok with Access-Control headers", async () => {
  const res = await handleRequest(new Request("https://x/finance/collections", { method: "OPTIONS" }), goodConfig);
  assertEquals(res.status, 200);
  assertEquals(await res.text(), "ok");
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
  assertEquals(res.headers.get("Access-Control-Allow-Methods")?.includes("POST"), true);
});

Deno.test("QA-B-068: CORS headers are present on a normal 200 AND on an error response", async () => {
  const ok = await handleRequest(new Request("https://x/health"), goodConfig);
  assertEquals(ok.headers.get("Access-Control-Allow-Origin"), "*");
  // ICA-F1: authenticate so the probe reaches the 404 (not the pre-dispatch 401 gate).
  const notFound = await handleRequest(await tokenReq("POST", "/nope", []), goodConfig);
  assertEquals(notFound.status, 404);
  assertEquals(notFound.headers.get("Access-Control-Allow-Origin"), "*");
});

// ── QA-B-069 — correlation id ────────────────────────────────────────────────
Deno.test("QA-B-069: a correlation id is generated when none is supplied", async () => {
  const res = await handleRequest(new Request("https://x/health"), goodConfig);
  const cid = res.headers.get("x-correlation-id");
  assertEquals(typeof cid === "string" && cid.length > 0, true);
});

Deno.test("QA-B-069: a supplied x-correlation-id is propagated to the response", async () => {
  const res = await handleRequest(
    new Request("https://x/health", { headers: { "x-correlation-id": "trace-abc-123" } }),
    goodConfig,
  );
  assertEquals(res.headers.get("x-correlation-id"), "trace-abc-123");
});

// ── QA-B-067 — 4xx body validation before the DB ─────────────────────────────
Deno.test("QA-B-067: a write with a missing required field is 422 before the DB (finance collect)", async () => {
  const req = await tokenReq("POST", "/finance/collections", ["manageFinance"],
    { amount_collected: 5000, payment_method: "cash" }); // no invoice_id
  const res = await handleRequest(req, goodConfig);
  assertEquals(res.status, 422);
});

Deno.test("QA-B-067: a malformed JSON body is rejected (not a 500) on a gated write", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const req = new Request("https://x/finance/collections", {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: "{not valid json",
  });
  const res = await handleRequest(req, goodConfig);
  // readJson swallows the parse error → handler reports a 4xx validation envelope,
  // never an unhandled 500.
  assertEquals(res.status >= 400 && res.status < 500, true);
});

// ── QA-B-063 — 500 SERVER_ERROR when a handler throws ────────────────────────
// The codebase is comprehensively guarded: every DB-free request returns a
// structured envelope (401/403/404/422/402/503), so the outer SERVER_ERROR catch
// is a true safety net. We exercise it via the universal idempotency dispatch:
// a mutating route carrying an `Idempotency-Key` makes `dispatchWithIdempotency`
// reach the store BEFORE the per-handler tenant-context guard, and its throw
// propagates to handleRequest's catch → 500 SERVER_ERROR envelope.
Deno.test("QA-B-063: an uncaught throw during dispatch is mapped to a 500 SERVER_ERROR envelope", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const req = new Request("https://x/finance/collections", {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
      "idempotency-key": "qa-b-063-key",
    },
    body: JSON.stringify({ invoice_id: "inv-1", amount_collected: 5000, payment_method: "cash" }),
  });
  const res = await handleRequest(req, goodConfig);
  assertEquals(res.status, 500);
  const env = await res.json();
  assertEquals(env.data, null);
  assertEquals(env.error.code, "SERVER_ERROR");
  // ENG-7 (SEC-6): the 500 body carries a GENERIC message — no raw internal /
  // DB / stack detail leaks to the client (the real detail is logged only).
  assertEquals(env.error.message, "An unexpected error occurred.");
  // CORS + correlation id are still attached on the 500 path.
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
  assertEquals((res.headers.get("x-correlation-id") ?? "").length > 0, true);
});

// Control: the SAME write WITHOUT the idempotency key passes the gate and reaches
// the (unconfigured) DB → 503, proving the 500 above is the dispatch throw, not the gate.
Deno.test("QA-B-063: the same write without an idempotency key reaches the DB (503), not a 500", async () => {
  const req = await tokenReq("POST", "/finance/collections", ["manageFinance"],
    { invoice_id: "inv-1", amount_collected: 5000, payment_method: "cash" });
  const res = await handleRequest(req, goodConfig);
  assertEquals(res.status, 503);
});
