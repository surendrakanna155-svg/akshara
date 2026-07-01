// QW4 · QA-B-013 / QA-B-015 / QA-B-016 — Finance router ROUTE/RBAC contract.
//
// DB-free route-contract proof for the finance module (route map in
// finance_router.ts → matchFinanceRoute). For every registered route we assert
// the router resolves it to the correct handler and that the handler enforces
// its permission slug:
//   • a token that LACKS the route's slug → 403 FORBIDDEN (gate blocked), and
//   • a token that HOLDS it → 503 TENANT_DB_NOT_CONFIGURED (gate + scope passed,
//     handler reached the unconfigured tenant DB — the DB-free "authorized"
//     proxy, exactly as in finance_collections_route_contract_test.ts).
// An UNREGISTERED /finance/* path → 404 NOT_FOUND (routeFinance owns the prefix
// and returns its own 404 envelope, not null).
//
// The permission slug for each route was read directly from the handler's
// `requirePermission(claims, "…")` call (never guessed). Read routes gate on
// viewFinance, write routes on manageFinance, refund approve/reject on
// approveRefunds, intelligence on viewFinanceIntelligence / executive, and
// inventory-reconciliation on viewFinance.
//
// What this does NOT prove (live/RLS remainder, covered by the live cert):
// real 200 payloads, persisted rows, and per-tenant row isolation.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeFinance } from "./finance_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(
  perms: string[],
  over: Partial<AccessTokenClaims> = {},
): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "financeAdmin",
    role_slugs: ["financeAdmin"],
    primary_role: "financeAdmin",
    permissions: perms,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

async function call(
  method: string,
  path: string,
  perms: string[],
  body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return await routeFinance(req, config, method, path);
}

// ── The full registered route map (28 routes), each with its real slug ────────
// `holder` = a permission set that should pass the gate (→ 503).
// `other`  = a permission set that lacks the slug (→ 403). We use viewInventory
//            as a benign non-finance permission for read routes, and viewFinance
//            (read-only) for write routes so the deny is the WRITE escalation.
const ID = "00000000-0000-0000-0000-000000000001";

interface RouteCase {
  method: string;
  path: string;
  holder: string[]; // grants access → 503
  other: string[]; // lacks the required slug → 403
}

const routes: RouteCase[] = [
  // dashboard / intelligence / executive
  { method: "GET", path: "/finance/dashboard", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: "/finance/intelligence/copilot", holder: ["viewFinanceIntelligence"], other: ["viewFinance"] },
  // executive OR-gates the two slugs (viewFinanceExecutiveDashboard OR
  // viewFinanceIntelligence) via requireAnyPermission — EITHER alone authorizes
  // (here: only viewFinanceIntelligence → pass); a token holding NEITHER (viewFinance) is denied.
  { method: "GET", path: "/finance/intelligence/executive", holder: ["viewFinanceIntelligence"], other: ["viewFinance"] },
  // inventory-reconciliation (gate: viewFinance)
  { method: "GET", path: "/finance/inventory-reconciliation/dashboard", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: "/finance/inventory-reconciliation/timeline", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: "/finance/inventory-reconciliation/goods-receipts", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: "/finance/inventory-reconciliation/postings", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: `/finance/inventory-reconciliation/goods-receipts/${ID}`, holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: `/finance/inventory-reconciliation/vendors/${ID}/transactions`, holder: ["viewFinance"], other: ["viewInventory"] },
  // fee structures
  { method: "GET", path: "/finance/fee-structures", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "POST", path: "/finance/fee-structures", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "PATCH", path: `/finance/fee-structures/${ID}/archive`, holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "GET", path: `/finance/fee-structures/${ID}`, holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "PUT", path: `/finance/fee-structures/${ID}`, holder: ["manageFinance"], other: ["viewFinance"] },
  // fee assignments
  { method: "GET", path: "/finance/fee-assignments", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "POST", path: "/finance/fee-assignments", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "POST", path: "/finance/fee-assignment/assign", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "PATCH", path: `/finance/fee-assignments/${ID}/cancel`, holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "GET", path: `/finance/fee-assignments/${ID}`, holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: `/finance/student-accounts/${ID}`, holder: ["viewFinance"], other: ["viewInventory"] },
  // FIN-2: printable student ledger (read → viewFinance)
  { method: "GET", path: `/finance/student-accounts/${ID}/ledger`, holder: ["viewFinance"], other: ["viewInventory"] },
  // collections
  { method: "GET", path: "/finance/collections", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "POST", path: "/finance/collections", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "GET", path: "/finance/collections/daily-summary", holder: ["viewFinance"], other: ["viewInventory"] },
  // FIN-D3: cancelled register (read → viewFinance)
  { method: "GET", path: "/finance/collections/cancelled", holder: ["viewFinance"], other: ["viewInventory"] },
  // FIN-D3: cancel now requires a reason body — a holder with no body trips the
  // 422 reason-validation that runs after the gate (still gate-passed).
  { method: "POST", path: `/finance/collections/${ID}/cancel`, holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "GET", path: `/finance/collections/${ID}`, holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: `/finance/receipts/${ID}`, holder: ["viewFinance"], other: ["viewInventory"] },
  // invoices
  { method: "GET", path: "/finance/invoices", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "POST", path: `/finance/invoices/${ID}/issue`, holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "POST", path: `/finance/invoices/${ID}/cancel`, holder: ["manageFinance"], other: ["viewFinance"] },
  // FIN-D5: waive a single invoice's late fee (write → manageFinance)
  { method: "POST", path: `/finance/invoices/${ID}/waive-late-fee`, holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "GET", path: `/finance/invoices/${ID}`, holder: ["viewFinance"], other: ["viewInventory"] },
  // refunds (approve/reject gate on approveRefunds — see QA-B-015)
  { method: "GET", path: "/finance/refunds", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "POST", path: "/finance/refunds", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "POST", path: `/finance/refunds/${ID}/approve`, holder: ["approveRefunds"], other: ["manageFinance"] },
  { method: "POST", path: `/finance/refunds/${ID}/reject`, holder: ["approveRefunds"], other: ["manageFinance"] },
  { method: "GET", path: `/finance/refunds/${ID}`, holder: ["viewFinance"], other: ["viewInventory"] },
  // discounts
  { method: "GET", path: "/finance/discounts", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "POST", path: "/finance/discounts", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "PUT", path: `/finance/discounts/${ID}`, holder: ["manageFinance"], other: ["viewFinance"] },
  // offline payments
  { method: "POST", path: "/finance/payments/offline", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "GET", path: "/finance/payments/offline", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "POST", path: `/finance/payments/offline/${ID}/reconcile`, holder: ["manageFinance"], other: ["viewFinance"] },
  // QR / UPI sessions
  { method: "POST", path: "/finance/payments/qr", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "POST", path: `/finance/payments/qr/${ID}/confirm`, holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "GET", path: `/finance/payments/qr/${ID}`, holder: ["viewFinance"], other: ["viewInventory"] },
  // FIN-R: fee-recovery CRM (reads gate viewFinance, writes gate manageFinance)
  { method: "GET", path: "/finance/recovery/dashboard", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "POST", path: "/finance/recovery/contacts", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "GET", path: `/finance/recovery/contacts/${ID}`, holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: "/finance/recovery/promises", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "POST", path: "/finance/recovery/promises", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "POST", path: `/finance/recovery/promises/${ID}/resolve`, holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "GET", path: "/finance/recovery/targets", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "POST", path: "/finance/recovery/targets", holder: ["manageFinance"], other: ["viewFinance"] },
  // FIN-D5: late-fee accrual (write → manageFinance)
  { method: "POST", path: "/finance/late-fees/accrue", holder: ["manageFinance"], other: ["viewFinance"] },
  // FIN-D1: day-close lock (read → viewFinance; close/reopen → manageFinance)
  { method: "GET", path: "/finance/day-close", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "POST", path: "/finance/day-close", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "POST", path: `/finance/day-close/2026-07-01/reopen`, holder: ["manageFinance"], other: ["viewFinance"] },
  // defaulters / reports / settings
  { method: "GET", path: "/finance/defaulters", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: "/finance/reports", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: "/finance/settings", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "PUT", path: "/finance/settings", holder: ["manageFinance"], other: ["viewFinance"] },
  // scholarships
  { method: "POST", path: "/finance/scholarships", holder: ["manageFinance"], other: ["viewFinance"] },
  { method: "PUT", path: `/finance/scholarships/${ID}`, holder: ["manageFinance"], other: ["viewFinance"] },
];

Deno.test("QA-B-013: every registered finance route resolves to a handler and enforces its permission slug", async () => {
  for (const r of routes) {
    // Holder of the route's slug → gate + school scope pass. The request then
    // either reaches the (unconfigured) tenant DB (503) or — for writes invoked
    // with no body here — trips body validation that runs AFTER the gate but
    // BEFORE the DB (422). Both 503 and 422 prove the permission gate let the
    // caller through (i.e. the slug authorized the route); only 401/403/404
    // would mean the gate/route rejected it.
    const holderRes = await call(r.method, r.path, r.holder);
    const gatePassed = holderRes?.status === 503 || holderRes?.status === 422;
    assertEquals(
      gatePassed,
      true,
      `${r.method} ${r.path} with [${r.holder}] expected gate-passed (503 or 422) but got ${holderRes?.status}`,
    );
    // Caller lacking the slug → 403 FORBIDDEN (the gate blocked the escalation).
    const otherRes = await call(r.method, r.path, r.other);
    assertEquals(
      otherRes?.status,
      403,
      `${r.method} ${r.path} with [${r.other}] expected 403 (missing slug)`,
    );
  }
});

Deno.test("QA-B-013: an unregistered finance path returns 404 NOT_FOUND", async () => {
  const res = await call("GET", "/finance/not-a-real-route", ["viewFinance", "manageFinance"]);
  assertEquals(res?.status, 404);
  const env = await res!.json();
  assertEquals(env.error.code, "NOT_FOUND");
  assertEquals(env.data, null);
});

Deno.test("QA-B-013: a non-finance prefix is not owned by the finance router (returns null)", async () => {
  // routeFinance only owns /finance/* — anything else must fall through (null)
  // so the dispatcher can try the next router. Provable from the prefix guard.
  const token = await signAccessToken(SECRET, claims(["viewFinance"]), 900);
  const req = new Request("https://x/transport/vehicles", {
    method: "GET",
    headers: { authorization: `Bearer ${token}` },
  });
  const res = await routeFinance(req, config, "GET", "/transport/vehicles");
  assertEquals(res, null);
});

Deno.test("QA-B-013: an unauthenticated caller is rejected with 401 before any route work", async () => {
  const req = new Request("https://x/finance/dashboard", { method: "GET" });
  const res = await routeFinance(req, config, "GET", "/finance/dashboard");
  assertEquals(res?.status, 401);
});

// ── QA-B-015: refund approve/reject is a SEPARATE verb from manageFinance ─────
// Anti-escalation: a token holding ONLY manageFinance (can create refunds) must
// NOT be able to approve/reject them — that requires the distinct approveRefunds
// slug. Read from finance_refunds_handlers.ts: handleApproveRefund /
// handleRejectRefund call requireRefundApproval → requirePermission("approveRefunds").

Deno.test("QA-B-015: refund APPROVE is denied for a manageFinance-only token (403, verb anti-escalation)", async () => {
  const res = await call("POST", `/finance/refunds/${ID}/approve`, ["manageFinance"]);
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-015: refund APPROVE passes the gate WITH approveRefunds (reaches DB, 503)", async () => {
  const res = await call("POST", `/finance/refunds/${ID}/approve`, ["approveRefunds"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-015: refund REJECT is denied for a manageFinance-only token (403)", async () => {
  const res = await call("POST", `/finance/refunds/${ID}/reject`, ["manageFinance"]);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-015: refund REJECT passes the gate WITH approveRefunds (503)", async () => {
  const res = await call("POST", `/finance/refunds/${ID}/reject`, ["approveRefunds"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-015: refund CREATE requires only manageFinance (passes the gate, 503) — create != approve", async () => {
  // Proves the verbs are distinct in BOTH directions: manageFinance is enough to
  // request a refund but NOT to approve one.
  const res = await call("POST", "/finance/refunds", ["manageFinance"], {
    refund_amount: 100,
    reason: "overpayment",
  });
  assertEquals(res?.status, 503);
});

// ── QA-B-016: PUT /finance/settings persistence gate ──────────────────────────
// Read from finance_settings_handlers.ts: handleUpdateSettings gates on
// requireFinanceWrite → requirePermission("manageFinance"). A holder reaches the
// persistence path (503 DB-free proxy); a non-holder is denied (403). The actual
// row upsert is covered by the repository test + live cert.

Deno.test("QA-B-016: PUT /finance/settings persists for a manageFinance holder (reaches DB, 503)", async () => {
  const res = await call("PUT", "/finance/settings", ["manageFinance"], {
    academic_year: "2026-27",
    updates: [{ section_id: "general", item_id: "currency", value: "INR" }],
  });
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-016: PUT /finance/settings is denied for a viewFinance-only (read) token (403)", async () => {
  const res = await call("PUT", "/finance/settings", ["viewFinance"], {
    updates: [{ section_id: "general", item_id: "currency", value: "INR" }],
  });
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-016: PUT /finance/settings rejects a missing body (422) before the DB", async () => {
  // body required → 422 even for a holder, proving validation fires pre-persist.
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const req = new Request("https://x/finance/settings", {
    method: "PUT",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    // no body
  });
  const res = await routeFinance(req, config, "PUT", "/finance/settings");
  assertEquals(res?.status, 422);
});

Deno.test("QA-B-016: GET /finance/settings is readable by a viewFinance holder (503) and denied otherwise (403)", async () => {
  const ok = await call("GET", "/finance/settings", ["viewFinance"]);
  assertEquals(ok?.status, 503);
  const denied = await call("GET", "/finance/settings", ["viewInventory"]);
  assertEquals(denied?.status, 403);
});
