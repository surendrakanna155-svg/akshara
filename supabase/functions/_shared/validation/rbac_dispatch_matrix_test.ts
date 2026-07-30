// API-101 — **the dispatcher matrix.** The RBAC suite finally dispatches.
//
// ## What was wrong
//
// `rbac_full_matrix_test.ts` and `rbac_route_validation_test.ts` both iterate the
// inventory and call the *pure function* `requirePermission(claims, permission)`.
// Neither constructs a `Request`, calls `matchModuleRoute`, or invokes a handler.
// They prove that a 20-line permission comparator works. They cannot see whether
// the ROUTE applies that comparator — so a route with no gate, or the wrong gate,
// passed the entire suite by simply not being listed, and 246 mutating routes
// were not listed.
//
// This test asks the real thing. For every mutating route the dispatcher serves
// (derived, not hand-listed), it signs a VALID token carrying **zero
// permissions** and dispatches through `handleRequest`. An authenticated
// non-holder must be refused with 403.
//
// Nothing is written: no database is configured in the test environment, so a
// handler that gets past its gate stops at a 503 before it can touch data. That
// 503 is the signal — it means the request reached the database *without being
// refused*.
//
// ## Why an exception table exists, and why it is still a gate
//
// 32 mutating routes do not refuse a zero-permission caller today. Each is
// recorded below with its category and the defect that owns it. That is not a
// loophole — it is the point:
//
//   * the list can only SHRINK: a route that starts refusing correctly must be
//     removed from it, or `no stale exceptions` fails;
//   * a NEW mutating route that does not refuse fails immediately, because it is
//     not on the list. The mechanism that let two attendance routes ship
//     unaudited is closed whether or not the 32 are fixed;
//   * the ceiling is asserted, so the list cannot quietly grow.
//
// Fixing the 32 is not this wave's work: 14 of them are the
// validate-before-authorise defect (API-118 / W1.17), and the rest gate on data
// or persona scope rather than a permission.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  assertDerivationFloor,
  deriveRouteTable,
  type DerivedRoute,
  mutatingRoutes,
  routeKey,
} from "./rbac_route_derivation.ts";

/**
 * Mutating routes that do NOT answer 403 to an authenticated caller holding zero
 * permissions, each with the reason. **Append only with a reason; delete freely.**
 */
const DISPATCH_GATE_EXCEPTIONS: Record<string, string> = {
  // ── (a) Validates BEFORE it authorises (API-118 / W1.17) ──────────────────
  // The route rejects the request body/query and discloses its parameter
  // contract to a caller it has not yet authorised. Authorise first, then
  // validate. Until W1.17 lands these answer 422.
  "POST /approvals": "API-118: 422 'Missing required approval fields' before authorisation",
  "POST /audit/events/batch": "API-118: 422 'events array is required' before authorisation",
  "POST /complaints/:id/status": "API-118: 422 status-enum disclosure before authorisation",
  "POST /homework/attachment/download": "API-118: 422 'storage_path is required' before authorisation",
  "POST /intelligence/recommendations/feedback": "API-118: 422 'itemKey required' before authorisation",
  "POST /inventory/distribution/items/:id/status": "API-118: 422 'status is required' before authorisation",
  "POST /legal/accept": "API-118: 422 'acceptances must be a non-empty array' before authorisation",
  "POST /parent/attendance/corrections": "API-118: 422 'sisStudentId is required' before authorisation",
  "POST /parent/device-tokens/register": "API-118: 422 'token is required' before authorisation",
  "POST /parent/device-tokens/unregister": "API-118: 422 'token is required' before authorisation",
  "POST /parent/leave/:id/attachment": "API-118: 422 'attachment_name is required' before authorisation",
  "POST /parent/notifications/mark-read": "API-118: 422 'notification_id is required' before authorisation",
  "POST /student/device-tokens/register": "API-118: 422 'token is required' before authorisation",
  "POST /student/device-tokens/unregister": "API-118: 422 'token is required' before authorisation",
  "POST /student/notifications/mark-read": "API-118: 422 'notification_id is required' before authorisation",

  // ── (b) The gate is DATA-dependent — it loads the row, then authorises ────
  // `decideOne` reads the approval and gates on `approvalPermissionForType(row.type)`,
  // so with no database the request 503s before the check runs. The gate is real;
  // this harness cannot reach it. A DB-backed matrix would be needed to prove it,
  // and that is a bigger lane than this wave.
  "POST /approvals/:id/approve": "data-dependent gate (approvalPermissionForType(row.type)) — 503 before the check",
  "POST /approvals/:id/reject": "data-dependent gate (approvalPermissionForType(row.type)) — 503 before the check",
  "POST /approvals/:id/cancel":
    "data-dependent gate (approve-authority OR requester) — and it throws 500 rather than 503 on the " +
    "unconfigured-DB path, unlike its approve/reject siblings. Worth a look when W1.17 touches this router.",
  "POST /attendance-auth/face/enroll": "data-dependent gate (staff enrolment record) — 503 before the check",
  "POST /attendance-auth/face/revoke": "data-dependent gate (staff enrolment record) — 503 before the check",
  "POST /communications/notifications/:id/acknowledge": "recipient-ownership gate (row-scoped) — 503 before the check",
  "POST /parent/leave/:id/cancel": "requester-ownership gate (row-scoped) — 503 before the check",

  // ── (c) Persona-scope routes: the gate is SCOPE, not a permission ─────────
  // These serve the parent/student/teacher personas, which hold no school
  // permissions by design; the boundary is `requireParentScope` / child linkage /
  // sender identity, enforced after the row is loaded. A school-scope probe is
  // the wrong instrument for them, not evidence that they are open.
  "POST /parent/messages": "parent-persona: scope + child-linkage gate, not a permission",
  "POST /parent/messages/send": "parent-persona: scope + child-linkage gate, not a permission",
  "POST /parent/notifications/mark-all-read": "parent-persona: scope gate, not a permission",
  "POST /parent/payments/initiate": "parent-persona: scope + child-linkage gate, not a permission",
  "POST /parent/payments/confirm": "parent-persona: scope + child-linkage gate, not a permission",
  "POST /student/notifications/mark-all-read": "student-persona: scope gate, not a permission",
  "POST /teacher/leave": "teacher-persona: self-service, gated on the caller's own identity",
  "POST /teacher/messages": "teacher-persona: gated on the caller's own thread membership",
  "POST /teacher/messages/send": "teacher-persona: gated on the caller's own thread membership",

  // ── (d) Authenticated by another means entirely ──────────────────────────
  "POST /communications/delivery/webhook":
    "HMAC over the raw body (SEC-1). Deliberately permission:null in the inventory; a JWT gate here would be wrong.",
};

/** Today's count. The list may shrink; growing it is a deliberate, visible act. */
const EXCEPTION_CEILING = 32;

let cachedTable: DerivedRoute[] | null = null;
async function table(): Promise<DerivedRoute[]> {
  if (cachedTable === null) {
    cachedTable = await deriveRouteTable();
    assertDerivationFloor(cachedTable);
  }
  return cachedTable;
}

const ruleId = (r: DerivedRoute) => `${r.method} ${r.path}`;

Deno.test("API-101: every mutating route REFUSES an authenticated caller holding no permissions", async () => {
  const offenders = mutatingRoutes(await table())
    .filter((r) => r.gateStatus !== 403)
    .filter((r) => !(ruleId(r) in DISPATCH_GATE_EXCEPTIONS))
    .map((r) => `${ruleId(r)} -> ${r.gateStatus} ${r.gateMessage.slice(0, 90)}`);
  assertEquals(
    offenders,
    [],
    `These mutating routes were DISPATCHED with a valid token carrying zero ` +
      `permissions and did not answer 403. A 422 discloses the parameter ` +
      `contract to an unauthorised caller; a 503 means the request reached the ` +
      `database without being refused.\n\n` +
      `Gate the route, or — if it genuinely authorises by another means — add it ` +
      `to DISPATCH_GATE_EXCEPTIONS with the reason:\n${offenders.join("\n")}`,
  );
});

Deno.test("API-101: the exception list has no stale entries (it can only shrink)", async () => {
  const live = new Map(mutatingRoutes(await table()).map((r) => [ruleId(r), r]));
  const stale: string[] = [];
  for (const id of Object.keys(DISPATCH_GATE_EXCEPTIONS)) {
    const route = live.get(id);
    if (!route) {
      stale.push(`${id} — no such mutating route any more; delete the entry`);
    } else if (route.gateStatus === 403) {
      stale.push(`${id} — now refuses correctly (403); delete the entry`);
    }
  }
  assertEquals(stale, [], stale.join("\n"));
});

Deno.test("API-101: the exception list cannot quietly grow", () => {
  const size = Object.keys(DISPATCH_GATE_EXCEPTIONS).length;
  assert(
    size <= EXCEPTION_CEILING,
    `${size} exceptions declared, ceiling is ${EXCEPTION_CEILING}. Adding an ` +
      `ungated mutating route is a decision, not a formality — lower the ceiling ` +
      `as routes are fixed, never raise it to make a build pass.`,
  );
  for (const [id, reason] of Object.entries(DISPATCH_GATE_EXCEPTIONS)) {
    assert(reason.length > 20, `${id} has no real justification`);
  }
});

Deno.test("API-101: the money and governance writes are gated — asserted BY DISPATCH", async () => {
  // The specific routes the defect register named. Expressed as a dispatch, which
  // is the thing that was impossible before: the old suite could only ask
  // `requirePermission` a question it already knew the answer to.
  const byId = new Map((await table()).map((r) => [ruleId(r), r]));
  for (
    const [id, permission] of [
      ["POST /finance/collections", "manageFinance"],
      ["POST /finance/refunds", "manageFinance"],
      ["POST /finance/day-close", "manageFinance"],
      ["POST /finance/discounts", "manageFinance"],
      ["POST /finance/fee-assignments", "manageFinance"],
      ["POST /finance/late-fees/accrue", "manageFinance"],
      ["PATCH /academics/exams/marks/:id", "manageExamMarks"],
      ["POST /academics/exams/:id/marks/batch", "manageExamMarks"],
      ["PATCH /attendance/corrections/:id/status", "approveAttendanceCorrection"],
      ["POST /identity/roles", "manageManagement"],
    ] as const
  ) {
    const route = byId.get(id);
    assert(route, `${id} is not in the derived route table`);
    assertEquals(route!.gateStatus, 403, `${id} did not refuse a non-holder`);
    assertEquals(
      route!.requiredPermission ?? route!.requiredAnyOf?.[0],
      permission,
      `${id} enforces a different permission than expected`,
    );
  }
});

Deno.test("API-101: reads that do not refuse a non-holder are reported, not hidden", async () => {
  // Not an assertion of zero — reads are a wider surface than this wave and some
  // legitimately gate on persona scope. But the number is pinned, so the read
  // surface cannot quietly open further. API-111 (`viewPayments` enforced
  // nowhere) lives in here.
  const open = (await table()).filter(
    (r) => r.method === "GET" && r.gateStatus !== 403,
  );
  assert(
    open.length <= 17,
    `${open.length} GET routes do not refuse a zero-permission caller (was 17). ` +
      `Newly-open reads:\n${open.map(ruleId).join("\n")}`,
  );
});
