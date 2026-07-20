// DB-free HTTP-level tests for the Certificate Request Desk, mirroring the
// established route-contract pattern (see sis_conversion_handlers_test.ts
// #5): with no ERP_TENANT_DATABASE_URL / SUPABASE_* configured,
// authenticateRequest's session check short-circuits (assertSessionValid
// returns null when supabaseUrl/supabaseServiceRoleKey are unset), so a
// request that clears every permission gate proceeds all the way to
// withTenantContext and fails there with a deterministic 503
// TENANT_DB_NOT_CONFIGURED — proving the gate order (401 -> 403 -> reaches DB)
// without needing a real Postgres connection. Full happy-path behaviour
// (create/list/get/cancel and the request->approval linkage) is covered at
// the repository/function level in certificate_desk_repository_test.ts,
// certificate_desk_approval_effect_test.ts, and certificate_desk_raise_flow_test.ts.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeCertificateDesk } from "./certificate_desk_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "officeStaff",
    role_slugs: ["officeStaff"],
    primary_role: "officeStaff",
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
  over: Partial<AccessTokenClaims> | null,
  body?: unknown,
): Promise<Response> {
  const init: RequestInit = { method };
  if (over) {
    const token = await signAccessToken(SECRET, claims(over.permissions ?? [], over), 900);
    init.headers = { authorization: `Bearer ${token}` };
  }
  if (body !== undefined) {
    init.headers = { ...(init.headers ?? {}), "content-type": "application/json" };
    init.body = JSON.stringify(body);
  }
  // Mirrors routePath(): the router matches on the PATHNAME only; the query
  // string (if any) is read independently by the handler via new URL(req.url).
  const pathname = path.split("?")[0]!;
  const res = await routeCertificateDesk(new Request(`https://x${path}`, init), config, method, pathname);
  if (res === null) throw new Error(`routeCertificateDesk returned null for ${method} ${path}`);
  return res;
}

// ─── router prefix contract ───────────────────────────────────────────────

Deno.test("routeCertificateDesk: returns null for a path outside its prefix (next router tries)", async () => {
  const res = await routeCertificateDesk(
    new Request("https://x/sis/students"),
    config,
    "GET",
    "/sis/students",
  );
  assertEquals(res, null);
});

Deno.test("routeCertificateDesk: an unmatched sub-path inside the prefix is a 404, not null", async () => {
  const res = await call("GET", "/certificate-requests/abc/def/ghi", { permissions: ["requestStudentCertificate"] });
  assertEquals(res.status, 404);
  assertEquals((await res.json()).error.code, "NOT_FOUND");
});

// ─── auth ──────────────────────────────────────────────────────────────────

Deno.test("POST /certificate-requests: unauthenticated -> 401", async () => {
  const res = await call("POST", "/certificate-requests", null, { certificateType: "bonafide", studentId: "s1" });
  assertEquals(res.status, 401);
});

Deno.test("GET /certificate-requests: unauthenticated -> 401", async () => {
  const res = await call("GET", "/certificate-requests", null);
  assertEquals(res.status, 401);
});

Deno.test("POST /certificate-requests/:id/cancel: unauthenticated -> 401", async () => {
  const res = await call("POST", "/certificate-requests/req-1/cancel", null);
  assertEquals(res.status, 401);
});

// ─── raise (POST /certificate-requests) — RBAC + scope ─────────────────────

Deno.test("POST /certificate-requests: without requestStudentCertificate -> 403", async () => {
  const res = await call("POST", "/certificate-requests", { permissions: [] }, {
    certificateType: "bonafide",
    studentId: "s1",
  });
  assertEquals(res.status, 403);
  assertEquals((await res.json()).error.code, "FORBIDDEN");
});

Deno.test("POST /certificate-requests: with the permission but student scope (neither school nor parent) -> 403", async () => {
  const res = await call(
    "POST",
    "/certificate-requests",
    { permissions: ["requestStudentCertificate"], scope: "student", student_id: "s1" },
    { certificateType: "bonafide", studentId: "s1" },
  );
  assertEquals(res.status, 403);
  assertEquals((await res.json()).error.code, "FORBIDDEN");
});

Deno.test("POST /certificate-requests: staff with the permission reaches the DB (503, no DB configured)", async () => {
  const res = await call(
    "POST",
    "/certificate-requests",
    { permissions: ["requestStudentCertificate"] },
    { certificateType: "bonafide", studentId: "s1" },
  );
  assertEquals(res.status, 503);
  assertEquals((await res.json()).error.code, "TENANT_DB_NOT_CONFIGURED");
});

Deno.test("POST /certificate-requests: parent WITH the permission reaches the DB (503) — parent scope is legitimate for raise", async () => {
  const res = await call(
    "POST",
    "/certificate-requests",
    { permissions: ["requestStudentCertificate"], scope: "parent", child_ids: ["child-1"] },
    { certificateType: "bonafide" },
  );
  assertEquals(res.status, 503);
});

Deno.test("POST /certificate-requests: parent requesting a NON-linked child is 403 before ever reaching the DB", async () => {
  const res = await call(
    "POST",
    "/certificate-requests",
    { permissions: ["requestStudentCertificate"], scope: "parent", child_ids: ["child-1"] },
    { certificateType: "bonafide", studentId: "not-my-child" },
  );
  assertEquals(res.status, 403);
  assertEquals((await res.json()).error.code, "FORBIDDEN");
});

Deno.test("POST /certificate-requests: parent with NO linked children at all -> 403", async () => {
  const res = await call(
    "POST",
    "/certificate-requests",
    { permissions: ["requestStudentCertificate"], scope: "parent", child_ids: [] },
    { certificateType: "bonafide" },
  );
  assertEquals(res.status, 403);
});

Deno.test("POST /certificate-requests: missing certificateType -> 422", async () => {
  const res = await call("POST", "/certificate-requests", { permissions: ["requestStudentCertificate"] }, {
    studentId: "s1",
  });
  assertEquals(res.status, 422);
});

Deno.test("POST /certificate-requests: an invalid certificateType -> 422 before ever reaching the DB", async () => {
  const res = await call("POST", "/certificate-requests", { permissions: ["requestStudentCertificate"] }, {
    studentId: "s1",
    certificateType: "diploma",
  });
  assertEquals(res.status, 422);
});

Deno.test("POST /certificate-requests: staff with no studentId in the body -> 422", async () => {
  const res = await call("POST", "/certificate-requests", { permissions: ["requestStudentCertificate"] }, {
    certificateType: "bonafide",
  });
  assertEquals(res.status, 422);
});

// ─── list / detail — RBAC + scope ───────────────────────────────────────────

Deno.test("GET /certificate-requests: without either requestStudentCertificate or approveCertificateRequest -> 403", async () => {
  const res = await call("GET", "/certificate-requests", { permissions: [] });
  assertEquals(res.status, 403);
});

Deno.test("GET /certificate-requests: approveCertificateRequest alone is enough -> reaches DB (503)", async () => {
  const res = await call("GET", "/certificate-requests", { permissions: ["approveCertificateRequest"] });
  assertEquals(res.status, 503);
});

Deno.test("GET /certificate-requests: an invalid ?status= filter is a 422 before reaching the DB", async () => {
  const res = await call(
    "GET",
    "/certificate-requests?status=not-a-real-status",
    { permissions: ["approveCertificateRequest"] },
  );
  assertEquals(res.status, 422);
});

Deno.test("GET /certificate-requests/:id: without permission -> 403", async () => {
  const res = await call("GET", "/certificate-requests/req-1", { permissions: [] });
  assertEquals(res.status, 403);
});

Deno.test("GET /certificate-requests/:id: with permission reaches the DB (503)", async () => {
  const res = await call("GET", "/certificate-requests/req-1", { permissions: ["requestStudentCertificate"] });
  assertEquals(res.status, 503);
});

// ─── cancel — staff-only by design (parent RLS has no UPDATE grant) ────────

Deno.test("POST /certificate-requests/:id/cancel: without either permission -> 403", async () => {
  const res = await call("POST", "/certificate-requests/req-1/cancel", { permissions: [] });
  assertEquals(res.status, 403);
});

Deno.test("POST /certificate-requests/:id/cancel: parent scope is denied even WITH requestStudentCertificate — cancel is staff-only", async () => {
  const res = await call(
    "POST",
    "/certificate-requests/req-1/cancel",
    { permissions: ["requestStudentCertificate"], scope: "parent", child_ids: ["child-1"] },
  );
  assertEquals(res.status, 403);
  const json = await res.json();
  assertEquals(json.error.code, "FORBIDDEN");
});

Deno.test("POST /certificate-requests/:id/cancel: staff with requestStudentCertificate reaches the DB (503)", async () => {
  const res = await call("POST", "/certificate-requests/req-1/cancel", { permissions: ["requestStudentCertificate"] });
  assertEquals(res.status, 503);
});

Deno.test("POST /certificate-requests/:id/cancel: staff with approveCertificateRequest reaches the DB (503)", async () => {
  const res = await call("POST", "/certificate-requests/req-1/cancel", { permissions: ["approveCertificateRequest"] });
  assertEquals(res.status, 503);
});
