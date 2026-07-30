// SCE-1 slice 3 — waiver repository: create/decide(SoD+race)/find/consume, DB-free.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  ClearanceWaiverError,
  type ClearanceWaiverRow,
  consumeWaiver,
  createWaiver,
  decideWaiver,
  findActiveWaiver,
  listPendingWaivers,
  revokeApprovedWaiver,
} from "./clearance_waiver_repository.ts";

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
      return Promise.resolve((results[i++] ?? []) as T[]);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

const SCOPE = { organizationId: "org-1", schoolId: "school-1" };
const pending = (over: Partial<ClearanceWaiverRow> = {}): ClearanceWaiverRow => ({
  id: "w1",
  student_id: "stu-1",
  lifecycle: "transfer_certificate",
  reason: "waive small balance",
  blocking_amount: "100",
  status: "pending",
  maker_id: "maker-1",
  checker_id: null,
  decided_at: null,
  consumed_by_issue_id: null,
  consumed_at: null,
  created_at: "2026-07-12T09:00:00Z",
  ...over,
});

Deno.test("createWaiver: inserts a pending row snapshotting the blocking amount + maker", async () => {
  const { db, calls } = mockDb([[pending()]]);
  await createWaiver(db, SCOPE, {
    studentId: "stu-1",
    lifecycle: "transfer_certificate",
    reason: "waive",
    blockingAmount: 100,
    makerId: "maker-1",
  });
  assert(calls[0].sql.includes("INSERT INTO student_clearance_waivers"));
  assert(calls[0].sql.includes("'pending'"));
  assertEquals(calls[0].args, ["org-1", "school-1", "stu-1", "transfer_certificate", "waive", 100, "maker-1"]);
});

Deno.test("decideWaiver: SoD — the maker can NEVER decide their own waiver (403)", async () => {
  const { db } = mockDb([[pending({ maker_id: "same-user" })]]);
  const err = await assertRejects(
    () => decideWaiver(db, SCOPE, "w1", "same-user", true),
    ClearanceWaiverError,
  );
  assertEquals((err as ClearanceWaiverError).code, "SELF_APPROVE_DENIED");
  assertEquals((err as ClearanceWaiverError).status, 403);
});

Deno.test("decideWaiver: an EMPTY actor id fails closed (SoD defense-in-depth, 403)", async () => {
  const { db } = mockDb([[pending({ maker_id: "some-maker" })]]);
  const err = await assertRejects(
    () => decideWaiver(db, SCOPE, "w1", "", true),
    ClearanceWaiverError,
  );
  assertEquals((err as ClearanceWaiverError).code, "SELF_APPROVE_DENIED");
  assertEquals((err as ClearanceWaiverError).status, 403);
});

Deno.test("decideWaiver: a DIFFERENT checker approves via a status-guarded claim UPDATE", async () => {
  const approved = pending({ status: "approved", checker_id: "checker-9" });
  const { db, calls } = mockDb([[pending()], [approved]]);
  const out = await decideWaiver(db, SCOPE, "w1", "checker-9", true);
  assertEquals(out.status, "approved");
  // The claim UPDATE is guarded on status='pending' (race-safe).
  assert(calls[1].sql.includes("UPDATE student_clearance_waivers"));
  assert(calls[1].sql.includes("status = 'pending'"));
  assertEquals(calls[1].args[3], "approved");
});

Deno.test("decideWaiver: losing the claim race → ALREADY_DECIDED (409)", async () => {
  const { db } = mockDb([[pending()], []]); // SELECT finds pending, claim returns 0 rows
  const err = await assertRejects(
    () => decideWaiver(db, SCOPE, "w1", "checker-9", true),
    ClearanceWaiverError,
  );
  assertEquals((err as ClearanceWaiverError).code, "WAIVER_ALREADY_DECIDED");
  assertEquals((err as ClearanceWaiverError).status, 409);
});

Deno.test("decideWaiver: approving a second waiver while one is already approved → clean 409 (uq_clearance_waivers_active), not a raw 500", async () => {
  const throwingDb = {
    queryObject: <T>(sql: string): Promise<T[]> => {
      if (sql.includes("SELECT")) return Promise.resolve([pending()] as T[]);
      // the claim UPDATE trips the one-approved-per-student partial unique index
      throw new Error('duplicate key value violates unique constraint "uq_clearance_waivers_active"');
    },
  } as unknown as TenantQueryClient;
  const err = await assertRejects(
    () => decideWaiver(throwingDb, SCOPE, "w2", "checker-9", true),
    ClearanceWaiverError,
  );
  assertEquals((err as ClearanceWaiverError).code, "WAIVER_ACTIVE_EXISTS");
  assertEquals((err as ClearanceWaiverError).status, 409);
});

Deno.test("decideWaiver: no pending waiver → NOT_FOUND", async () => {
  const { db } = mockDb([[]]);
  const err = await assertRejects(
    () => decideWaiver(db, SCOPE, "missing", "checker-9", true),
    ClearanceWaiverError,
  );
  assertEquals((err as ClearanceWaiverError).code, "WAIVER_NOT_FOUND");
});

Deno.test("findActiveWaiver: reads only status='approved' for (student, lifecycle)", async () => {
  const { db, calls } = mockDb([[pending({ status: "approved" })]]);
  const w = await findActiveWaiver(db, SCOPE, "stu-1", "transfer_certificate");
  assert(w !== null);
  assert(calls[0].sql.includes("status = 'approved'"));
  assertEquals(calls[0].args, ["org-1", "school-1", "stu-1", "transfer_certificate"]);
});

Deno.test("findActiveWaiver: none → null", async () => {
  const { db } = mockDb([[]]);
  assertEquals(await findActiveWaiver(db, SCOPE, "stu-1", "transfer_certificate"), null);
});

Deno.test("consumeWaiver: single-use — status-guarded UPDATE approved→consumed with the issue id", async () => {
  const consumed = pending({ status: "consumed", consumed_by_issue_id: "iss-7" });
  const { db, calls } = mockDb([[consumed]]);
  const out = await consumeWaiver(db, SCOPE, "stu-1", "transfer_certificate", "iss-7");
  assertEquals(out?.status, "consumed");
  assert(calls[0].sql.includes("status = 'consumed'"));
  assert(calls[0].sql.includes("status = 'approved'")); // guard: only an approved row is consumable
  assertEquals(calls[0].args[4], "iss-7");
});

Deno.test("consumeWaiver: nothing approved to consume → null (caller proceeds; gate cleared without a waiver)", async () => {
  const { db } = mockDb([[]]);
  assertEquals(await consumeWaiver(db, SCOPE, "stu-1", "transfer_certificate", "iss-7"), null);
});

Deno.test("listPendingWaivers: JOINs the student name + returns pending AND approved-unconsumed (deadlock revoke), pending first", async () => {
  const { db, calls } = mockDb([[{ ...pending(), student_name: "Asha Rao" }]]);
  const rows = await listPendingWaivers(db, SCOPE, 50);
  assertEquals(rows[0].student_name, "Asha Rao");
  assert(calls[0].sql.includes("LEFT JOIN students"));
  assert(calls[0].sql.includes("s.display_name AS student_name"));
  assert(calls[0].sql.includes("w.status = 'pending'"));
  // approved-but-un-consumed rows are included so a checker can REVOKE a stale one
  assert(calls[0].sql.includes("w.status = 'approved' AND w.consumed_by_issue_id IS NULL"));
  assert(calls[0].sql.includes("CASE w.status WHEN 'pending' THEN 0"));
});

Deno.test("revokeApprovedWaiver: an APPROVED waiver → rejected (status-guarded, frees the active-uq slot for a corrective waiver)", async () => {
  const revoked = pending({ status: "rejected", checker_id: "checker-9" });
  const { db, calls } = mockDb([[revoked]]);
  const out = await revokeApprovedWaiver(db, SCOPE, "w1", "checker-9");
  assertEquals(out.status, "rejected");
  assert(calls[0].sql.includes("status = 'approved'"), "only an approved row is revocable");
  assert(calls[0].sql.includes("SET status = 'rejected'"));
});

Deno.test("revokeApprovedWaiver: nothing approved (already consumed / pending) → WAIVER_NOT_REVOCABLE", async () => {
  const { db } = mockDb([[]]);
  const err = await assertRejects(
    () => revokeApprovedWaiver(db, SCOPE, "w1", "checker-9"),
    ClearanceWaiverError,
  );
  assertEquals((err as ClearanceWaiverError).code, "WAIVER_NOT_REVOCABLE");
});
