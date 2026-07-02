// PAR-D1 / PAR-3 — parent leave mutations (cancel + medical-certificate attach).
//
// Covers the two Parent backend items on the leave path:
//   - PAR-D1: a parent withdraws a PENDING leave for their OWN child (cancel).
//   - PAR-3:  a parent attaches a medical-certificate reference to that leave.
//
// Two layers are proven here without a live DB:
//   1. Repository logic (SQL-aware mock): own-child scoping (child_ids +
//      requester_user_id), pending-only immutability (409), and no cross-family
//      write (NOT_FOUND for another family's leave / a child not in child_ids).
//   2. Handler scope gate: a non-parent caller is rejected 403; a parent caller
//      passes the gate and reaches the (unconfigured) DB layer → 503. The
//      end-to-end positive path (real 200 + RLS) is covered by the live cert.

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import {
  attachParentLeaveDocument,
  cancelParentLeaveRequest,
  ParentLeaveNotFoundError,
  ParentLeaveNotPendingError,
} from "./pilot_operations_repository.ts";
import {
  handleParentLeaveAttachment,
  handleParentLeaveCancel,
} from "./pilot_operations_handlers.ts";
import { matchParentRoute } from "../parent/parent_router.ts";

const ORG = "org-1";
const SCHOOL = "school-1";
const PARENT_USER = "parent-1";
const OWN_CHILD = "student-own-1";
const LEAVE_ID = "11111111-1111-4111-8111-111111111111";

interface Capture {
  sql: string;
  args: unknown[];
}

// SQL-aware mock: routes each query to the first route whose `match` substring is
// found in the SQL and records every statement so the write is assertable. The
// SELECT (loadOwnChildLeave) and the UPDATE are distinguished by their keywords.
function mockDb(
  routes: Array<{
    match: string;
    rows: unknown[] | ((args: unknown[]) => unknown[]);
  }>,
  captures: Capture[],
): TenantQueryClient {
  return {
    queryObject: async <T>(sql: string, args: unknown[] = []) => {
      captures.push({ sql, args });
      const hit = routes.find((r) => sql.includes(r.match));
      const rows = typeof hit?.rows === "function" ? hit.rows(args) : hit?.rows;
      return (rows ?? []) as T[];
    },
  } as unknown as TenantQueryClient;
}

const baseInput = {
  organizationId: ORG,
  schoolId: SCHOOL,
  requesterUserId: PARENT_USER,
  childIds: [OWN_CHILD],
  leaveId: LEAVE_ID,
};

// ─── PAR-D1 — cancel (repository logic) ──────────────────────────────────────

Deno.test("PAR-D1 cancel: own PENDING leave flips to cancelled", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    // loadOwnChildLeave — the row exists, is pending, and belongs to own child.
    { match: "SELECT id, student_id, status", rows: [{ id: LEAVE_ID, student_id: OWN_CHILD, status: "pending" }] },
    // conditional UPDATE returns the row → cancel succeeded.
    { match: "SET status = 'cancelled'", rows: [{ id: LEAVE_ID, student_id: OWN_CHILD }] },
  ], captures);

  const result = await cancelParentLeaveRequest(db, baseInput);
  assertEquals(result, { id: LEAVE_ID, studentId: OWN_CHILD, status: "cancelled" });

  // The load bound requester_user_id + child_ids (own-child choke point), and the
  // UPDATE is guarded by status='pending' (immutability race guard).
  const load = captures.find((c) => c.sql.includes("SELECT id, student_id, status"))!;
  assertEquals(load.args, [ORG, SCHOOL, LEAVE_ID, PARENT_USER, [OWN_CHILD]]);
  const update = captures.find((c) => c.sql.includes("SET status = 'cancelled'"))!;
  assertEquals(update.sql.includes("status = 'pending'"), true);
});

Deno.test("PAR-D1 cancel: an already-decided leave is immutable (409)", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "SELECT id, student_id, status", rows: [{ id: LEAVE_ID, student_id: OWN_CHILD, status: "approved" }] },
  ], captures);

  const error = await assertRejects(
    () => cancelParentLeaveRequest(db, baseInput),
    ParentLeaveNotPendingError,
  );
  assertEquals(error.status, "approved");
  // No UPDATE was attempted on a non-pending leave.
  assertEquals(captures.some((c) => c.sql.includes("SET status = 'cancelled'")), false);
});

Deno.test("PAR-D1 cancel: a cancelled leave cannot be cancelled again (409)", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "SELECT id, student_id, status", rows: [{ id: LEAVE_ID, student_id: OWN_CHILD, status: "cancelled" }] },
  ], captures);
  await assertRejects(
    () => cancelParentLeaveRequest(db, baseInput),
    ParentLeaveNotPendingError,
  );
});

Deno.test("PAR-D1 cancel: another family's leave / child not in child_ids → NOT_FOUND", async () => {
  const captures: Capture[] = [];
  // The scoped SELECT (requester_user_id + child_ids) finds nothing for a leave
  // that belongs to another parent or a child not linked to this parent.
  const db = mockDb([
    { match: "SELECT id, student_id, status", rows: [] },
  ], captures);

  await assertRejects(
    () => cancelParentLeaveRequest(db, { ...baseInput, childIds: [OWN_CHILD] }),
    ParentLeaveNotFoundError,
  );
  // Never leaks the id: no UPDATE runs.
  assertEquals(captures.some((c) => c.sql.includes("SET status = 'cancelled'")), false);
});

Deno.test("PAR-D1 cancel: a parent with no linked children cannot cancel", async () => {
  const captures: Capture[] = [];
  const db = mockDb([{ match: "SELECT id, student_id, status", rows: [] }], captures);
  await assertRejects(
    () => cancelParentLeaveRequest(db, { ...baseInput, childIds: [] }),
    ParentLeaveNotFoundError,
  );
  // With no child_ids the repository short-circuits — no query is even issued.
  assertEquals(captures.length, 0);
});

Deno.test("PAR-D1 cancel: lost race (row decided concurrently) → 409", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "SELECT id, student_id, status", rows: [{ id: LEAVE_ID, student_id: OWN_CHILD, status: "pending" }] },
    // The conditional UPDATE returns NO row — approved between load and write.
    { match: "SET status = 'cancelled'", rows: [] },
  ], captures);
  await assertRejects(
    () => cancelParentLeaveRequest(db, baseInput),
    ParentLeaveNotPendingError,
  );
});

// ─── PAR-3 — attachment (repository logic) ───────────────────────────────────

Deno.test("PAR-3 attach: medical-certificate ref persists on own PENDING leave", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "SELECT id, student_id, status", rows: [{ id: LEAVE_ID, student_id: OWN_CHILD, status: "pending" }] },
    { match: "SET has_attachment = true", rows: [{ id: LEAVE_ID, student_id: OWN_CHILD }] },
  ], captures);

  const result = await attachParentLeaveDocument(db, {
    ...baseInput,
    attachmentName: "medical-cert.pdf",
    storagePath: null,
  });
  assertEquals(result, {
    id: LEAVE_ID,
    studentId: OWN_CHILD,
    attachmentName: "medical-cert.pdf",
  });
  // The attachment reference is written to the existing has_attachment +
  // attachment_name columns, guarded by requester_user_id + status='pending'.
  const update = captures.find((c) => c.sql.includes("SET has_attachment = true"))!;
  assertEquals(update.sql.includes("status = 'pending'"), true);
  assertEquals(update.args, [ORG, SCHOOL, LEAVE_ID, PARENT_USER, "medical-cert.pdf"]);
});

Deno.test("PAR-3 attach: rejects a foreign child's leave → NOT_FOUND", async () => {
  const captures: Capture[] = [];
  // The own-child scoped SELECT finds nothing → cannot attach to another child.
  const db = mockDb([{ match: "SELECT id, student_id, status", rows: [] }], captures);
  await assertRejects(
    () =>
      attachParentLeaveDocument(db, {
        ...baseInput,
        childIds: [OWN_CHILD], // a foreign child's leave never resolves under this scope
        attachmentName: "medical-cert.pdf",
        storagePath: null,
      }),
    ParentLeaveNotFoundError,
  );
  assertEquals(captures.some((c) => c.sql.includes("SET has_attachment = true")), false);
});

Deno.test("PAR-3 attach: an already-decided leave is immutable (409)", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "SELECT id, student_id, status", rows: [{ id: LEAVE_ID, student_id: OWN_CHILD, status: "rejected" }] },
  ], captures);
  await assertRejects(
    () =>
      attachParentLeaveDocument(db, {
        ...baseInput,
        attachmentName: "medical-cert.pdf",
        storagePath: null,
      }),
    ParentLeaveNotPendingError,
  );
});

// ─── Handler scope gate ──────────────────────────────────────────────────────

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function parentClaims(): AccessTokenClaims {
  return {
    sub: PARENT_USER,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
    role: "parent",
    role_slugs: ["parent"],
    primary_role: "parent",
    permissions: [],
    permissions_version: 1,
    scope: "parent",
    school_group_id: null,
    student_id: null,
    child_ids: [OWN_CHILD],
    session_id: "s1",
  };
}

function schoolClaims(): AccessTokenClaims {
  return {
    ...parentClaims(),
    sub: "staff-1",
    role: "officeStaff",
    role_slugs: ["officeStaff"],
    primary_role: "officeStaff",
    scope: "school",
    child_ids: [],
  };
}

function post(path: string, token: string, body: unknown): Request {
  return new Request(`https://x${path}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

Deno.test("PAR-D1 cancel handler rejects a non-parent (school) caller with 403", async () => {
  const token = await signAccessToken(SECRET, schoolClaims(), 900);
  const res = await handleParentLeaveCancel(
    post(`/parent/leave/${LEAVE_ID}/cancel`, token, {}),
    config,
    LEAVE_ID,
  );
  assertEquals(res.status, 403);
});

Deno.test("PAR-D1 cancel handler passes the parent scope gate (reaches DB → 503)", async () => {
  const token = await signAccessToken(SECRET, parentClaims(), 900);
  const res = await handleParentLeaveCancel(
    post(`/parent/leave/${LEAVE_ID}/cancel`, token, {}),
    config,
    LEAVE_ID,
  );
  // Parent scope accepted → reached the (unconfigured) DB layer, where the
  // own-child guard + RLS run in production.
  assertEquals(res.status, 503);
});

Deno.test("PAR-3 attach handler rejects a non-parent (school) caller with 403", async () => {
  const token = await signAccessToken(SECRET, schoolClaims(), 900);
  const res = await handleParentLeaveAttachment(
    post(`/parent/leave/${LEAVE_ID}/attachment`, token, { attachment_name: "cert.pdf" }),
    config,
    LEAVE_ID,
  );
  assertEquals(res.status, 403);
});

Deno.test("PAR-3 attach handler requires an attachment_name (422)", async () => {
  const token = await signAccessToken(SECRET, parentClaims(), 900);
  const res = await handleParentLeaveAttachment(
    post(`/parent/leave/${LEAVE_ID}/attachment`, token, {}),
    config,
    LEAVE_ID,
  );
  assertEquals(res.status, 422);
});

Deno.test("PAR-3 attach handler passes the parent scope gate (reaches DB → 503)", async () => {
  const token = await signAccessToken(SECRET, parentClaims(), 900);
  const res = await handleParentLeaveAttachment(
    post(`/parent/leave/${LEAVE_ID}/attachment`, token, { attachment_name: "cert.pdf" }),
    config,
    LEAVE_ID,
  );
  assertEquals(res.status, 503);
});

// ─── Router precedence — parent_router must NOT claim the new pilot paths ─────

Deno.test("parent router does NOT claim POST /parent/leave/:id/cancel (pilot-ops owns it)", () => {
  // Mirrors POST /parent/leave: the pilot router (which runs first in app.ts and
  // returns null on a miss) owns the canonical mobile_leave_requests write, so
  // parent_router must not shadow it.
  assertEquals(matchParentRoute("POST", `/parent/leave/${LEAVE_ID}/cancel`), null);
});

Deno.test("parent router does NOT claim POST /parent/leave/:id/attachment (pilot-ops owns it)", () => {
  assertEquals(matchParentRoute("POST", `/parent/leave/${LEAVE_ID}/attachment`), null);
});
