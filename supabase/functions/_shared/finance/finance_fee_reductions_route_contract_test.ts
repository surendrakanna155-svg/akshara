// STEP-5 — ROUTE contract for the fee-reduction maker-checker endpoints.
//
// The money math + SoD backstop are proven in
// finance_fee_reductions_repository_test.ts. This closes the HTTP-layer SoD:
//   * propose (maker)  requires manageFinance;
//   * approve/reject/reverse (checker) require the HIGHER approveFeeConcession
//     bar — a manageFinance-only token (a maker) is REFUSED at the RBAC gate
//     (verb anti-escalation), so the person who can propose cannot, by
//     permission alone, also approve. Combined with the repository-level
//     `created_by != approvedBy` guard, that is defense in depth.
//
// A 503 (TENANT_DB_NOT_CONFIGURED) means the gate PASSED and the handler reached
// the (unconfigured) DB — i.e. authorization let the request through.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import {
  handleApproveFeeReduction,
  handleProposeDiscountApplication,
  handleProposeScholarshipAward,
  handleRejectFeeReduction,
  handleReverseFeeReduction,
} from "./finance_fee_reductions_handlers.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;
const REDUCTION_ID = "fr000000-0000-4000-8000-000000000001";

function claims(permissions: string[]): AccessTokenClaims {
  return {
    sub: "user-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "financeAdmin",
    role_slugs: ["financeAdmin"],
    primary_role: "financeAdmin",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

function post(path: string, token: string, body: unknown): Request {
  return new Request(`https://x${path}`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

const validAward = {
  scholarshipId: "sch-1",
  invoiceId: "inv-1",
  reductionKind: "fixed",
  amount: 5000,
};

// ─── propose (maker) — manageFinance ────────────────────────────────────────

Deno.test("STEP-5 route: propose scholarship award is denied for a non-finance role (403)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewInventory"]), 900);
  const res = await handleProposeScholarshipAward(
    post("/finance/fee-reductions/scholarship-awards", token, validAward),
    config,
  );
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("STEP-5 route: propose scholarship award passes the gate WITH manageFinance (503)", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleProposeScholarshipAward(
    post("/finance/fee-reductions/scholarship-awards", token, validAward),
    config,
  );
  assertEquals(res.status, 503);
});

Deno.test("STEP-5 route: propose rejects a missing invoiceId (422) before the DB", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleProposeScholarshipAward(
    post("/finance/fee-reductions/scholarship-awards", token, { scholarshipId: "sch-1", amount: 5000 }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("STEP-5 route: propose rejects a percent reduction with no percent (422)", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleProposeScholarshipAward(
    post("/finance/fee-reductions/scholarship-awards", token, {
      scholarshipId: "sch-1",
      invoiceId: "inv-1",
      reductionKind: "percent",
    }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("STEP-5 route: propose discount application requires a discountRuleId (422)", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleProposeDiscountApplication(
    post("/finance/fee-reductions/discount-applications", token, {
      invoiceId: "inv-1",
      reductionKind: "percent",
      percent: 10,
    }),
    config,
  );
  assertEquals(res.status, 422);
});

// ─── approve / reject / reverse (checker) — approveFeeConcession ─────────────

Deno.test("STEP-5 route: APPROVE is DENIED for a manageFinance-only token (403) — a maker cannot self-approve by permission", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleApproveFeeReduction(
    post(`/finance/fee-reductions/${REDUCTION_ID}/approve`, token, {}),
    config,
    REDUCTION_ID,
  );
  assertEquals(res.status, 403);
});

Deno.test("STEP-5 route: APPROVE passes the gate WITH approveFeeConcession (503)", async () => {
  const token = await signAccessToken(SECRET, claims(["approveFeeConcession"]), 900);
  const res = await handleApproveFeeReduction(
    post(`/finance/fee-reductions/${REDUCTION_ID}/approve`, token, {}),
    config,
    REDUCTION_ID,
  );
  assertEquals(res.status, 503);
});

Deno.test("STEP-5 route: REJECT is denied for a manageFinance-only token (403)", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleRejectFeeReduction(
    post(`/finance/fee-reductions/${REDUCTION_ID}/reject`, token, {}),
    config,
    REDUCTION_ID,
  );
  assertEquals(res.status, 403);
});

Deno.test("STEP-5 route: REVERSE is denied for a manageFinance-only token (403), passes with approveFeeConcession (503)", async () => {
  const makerToken = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const denied = await handleReverseFeeReduction(
    post(`/finance/fee-reductions/${REDUCTION_ID}/reverse`, makerToken, {}),
    config,
    REDUCTION_ID,
  );
  assertEquals(denied.status, 403);

  const checkerToken = await signAccessToken(SECRET, claims(["approveFeeConcession"]), 900);
  const passed = await handleReverseFeeReduction(
    post(`/finance/fee-reductions/${REDUCTION_ID}/reverse`, checkerToken, {}),
    config,
    REDUCTION_ID,
  );
  assertEquals(passed.status, 503);
});

Deno.test("STEP-5 route: propose rejects an unauthenticated caller (401)", async () => {
  const res = await handleProposeScholarshipAward(
    new Request("https://x/finance/fee-reductions/scholarship-awards", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(validAward),
    }),
    config,
  );
  assertEquals(res.status, 401);
});
