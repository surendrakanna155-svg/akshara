// SLICE 4 / audit R4 — decideAttendanceRequest SoD + race guards (DB-free).
// mockDb follows the house repository-test style: a plain object cast to
// TenantQueryClient that returns queued results per call and records SQL+args.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type AttendanceRequestRow,
  decideAttendanceRequest,
  StaffAttendanceValidationError,
} from "./staff_check_in_repository.ts";

interface Call {
  sql: string;
  args: unknown[];
}

function mockDb(results: unknown[][]): { db: TenantQueryClient; calls: Call[] } {
  const calls: Call[] = [];
  let i = 0;
  const db = {
    queryObject: <T>(sql: string, args: unknown[] = []): Promise<T[]> => {
      calls.push({ sql, args });
      const result = (results[i] ?? []) as T[];
      i += 1;
      return Promise.resolve(result);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

const PENDING: AttendanceRequestRow = {
  id: "att_req_1",
  user_id: "staff-7",
  staff_name: "Asha",
  event_type: "check_in",
  reason: "camera broke",
  status: "pending",
  decided_by: null,
  decided_at: null,
  resulting_check_in_id: null,
  created_at: "2026-07-12T09:00:00Z",
};

Deno.test("decide: the requester can NEVER decide their own request (SoD, mirrors HR-3 leave)", async () => {
  const { db } = mockDb([[PENDING]]);
  const err = await assertRejects(
    () => decideAttendanceRequest(db, "org-1", "school-1", "att_req_1", "staff-7", true),
    StaffAttendanceValidationError,
  );
  assertEquals((err as StaffAttendanceValidationError).code, "SELF_APPROVE_DENIED");
});

Deno.test("decide: losing the claim race → REQUEST_ALREADY_DECIDED, and NO check-in is inserted", async () => {
  // SELECT finds the pending row, but the status-guarded claim UPDATE returns
  // zero rows (another approver committed first).
  const { db, calls } = mockDb([[PENDING], []]);
  const err = await assertRejects(
    () => decideAttendanceRequest(db, "org-1", "school-1", "att_req_1", "approver-1", true),
    StaffAttendanceValidationError,
  );
  assertEquals((err as StaffAttendanceValidationError).code, "REQUEST_ALREADY_DECIDED");
  // Exactly 2 queries ran: SELECT + failed claim. The check-in INSERT was never
  // reached — the race can no longer duplicate ledger rows.
  assertEquals(calls.length, 2);
  assert(calls[1]!.sql.includes("AND status = 'pending'"), "claim must be status-guarded");
});

Deno.test("decide: approve claims first, then records the check-in for the REQUESTER (not the approver)", async () => {
  const claimed: AttendanceRequestRow = { ...PENDING, status: "approved", decided_by: "approver-1" };
  const checkInRow = { id: "staff_chk_9", user_id: "staff-7" };
  const linked: AttendanceRequestRow = { ...claimed, resulting_check_in_id: "staff_chk_9" };
  const { db, calls } = mockDb([[PENDING], [claimed], [checkInRow], [linked]]);

  const out = await decideAttendanceRequest(
    db, "org-1", "school-1", "att_req_1", "approver-1", true,
  );

  assertEquals(out.request.resulting_check_in_id, "staff_chk_9");
  // Call order: SELECT pending → claim UPDATE → check-in INSERT → link UPDATE.
  assertEquals(calls.length, 4);
  const insert = calls[2]!;
  assert(insert.sql.includes("INSERT INTO staff_check_ins"));
  // The inserted user_id is the REQUESTER's (arg index 3 per the insert column
  // order), and the method is 'manual'.
  assertEquals(insert.args[3], "staff-7");
  assert(insert.args.includes("manual"));
});

Deno.test("decide: reject claims the row and never inserts a check-in", async () => {
  const rejected: AttendanceRequestRow = { ...PENDING, status: "rejected", decided_by: "approver-1" };
  const { db, calls } = mockDb([[PENDING], [rejected]]);

  const out = await decideAttendanceRequest(
    db, "org-1", "school-1", "att_req_1", "approver-1", false,
  );

  assertEquals(out.request.status, "rejected");
  assertEquals(out.checkIn, null);
  assertEquals(calls.length, 2);
});
