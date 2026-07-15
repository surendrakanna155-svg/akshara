// PRC-A gap fix — ROUTE contract for the bulk/class-wide fee-structure
// assignment endpoint (POST /finance/fee-assignments/bulk).
//
// The per-student assignment math + partial-failure (skip-a-duplicate)
// semantics are proven in finance_assignments_repository_test.ts. This closes
// the HTTP-layer contract: manageFinance is required (same gate as every
// other finance write here), and the body is validated BEFORE any DB work.
//
// A 503 (TENANT_DB_NOT_CONFIGURED) means the gate PASSED and the handler
// reached the (unconfigured) DB — i.e. authorization let the request through.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { handleBulkAssignFeeStructures } from "./finance_assignments_handlers.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;
const PATH = "/finance/fee-assignments/bulk";

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

function post(token: string, body: unknown): Request {
  return new Request(`https://x${PATH}`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

const validBody = {
  feeStructureId: "struct-1",
  academicYear: "2026-27",
  studentIds: ["stu-1", "stu-2"],
};

Deno.test("bulk assign route: 401 unauthenticated", async () => {
  const res = await handleBulkAssignFeeStructures(
    new Request(`https://x${PATH}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(validBody),
    }),
    config,
  );
  assertEquals(res.status, 401);
});

Deno.test("bulk assign route: 403 without manageFinance", async () => {
  const token = await signAccessToken(SECRET, claims(["viewFinance"]), 900);
  const res = await handleBulkAssignFeeStructures(post(token, validBody), config);
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("bulk assign route: passes the gate WITH manageFinance (503 — DB unconfigured)", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleBulkAssignFeeStructures(post(token, validBody), config);
  assertEquals(res.status, 503);
});

Deno.test("bulk assign route: missing student_ids is a 422 BEFORE any DB work", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleBulkAssignFeeStructures(
    post(token, { feeStructureId: "struct-1", academicYear: "2026-27" }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("bulk assign route: an empty student_ids array is a 422", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleBulkAssignFeeStructures(
    post(token, {
      feeStructureId: "struct-1",
      academicYear: "2026-27",
      studentIds: [],
    }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("bulk assign route: a missing fee_structure_id is a 422", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleBulkAssignFeeStructures(
    post(token, { academicYear: "2026-27", studentIds: ["stu-1"] }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("bulk assign route: a missing academic_year is a 422", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleBulkAssignFeeStructures(
    post(token, { feeStructureId: "struct-1", studentIds: ["stu-1"] }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("bulk assign route: accepts snake_case body keys too", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleBulkAssignFeeStructures(
    post(token, {
      fee_structure_id: "struct-1",
      academic_year: "2026-27",
      student_ids: ["stu-1"],
    }),
    config,
  );
  assertEquals(res.status, 503);
});

Deno.test("bulk assign route: an org-scope token is denied (school-operational-scope required)", async () => {
  const orgClaims: AccessTokenClaims = {
    ...claims(["manageFinance"]),
    scope: "organization",
    school_id: null,
    role: "organizationAdmin",
    role_slugs: ["organizationAdmin"],
    primary_role: "organizationAdmin",
  };
  const token = await signAccessToken(SECRET, orgClaims, 900);
  const res = await handleBulkAssignFeeStructures(post(token, validBody), config);
  assertEquals(res.status, 403);
});
