// COM-1 / COM-3 — per-broadcast delivery/read report + resend-to-unread.
//
// DB-free unit coverage of the service layer against a capturing fake
// TenantQueryClient (same in-file fake-db pattern as broadcast_batch_test.ts).
// The fake dispatches on SQL substrings so we can assert:
//   • getBroadcastReport returns the broadcast summary + aggregate counts
//     (total/sent/failed/pending/read/unread) + the unread-recipient roster, in
//     the API camelCase shape, off the notification_deliveries ledger.
//   • a broadcast id that isn't visible in scope → BroadcastNotFoundError (404).
//   • resendBroadcastToUnread re-enqueues ONLY the unread recipients (with the
//     broadcast_id stamped so the resend is itself tracked) and returns the
//     count; a broadcast with 0 unread returns { resent: 0 } and enqueues
//     nothing.
//
// The authoritative row-level RLS / real-count behaviour is covered by the live
// cert; this pins the SQL-building + branching + response shape.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  getBroadcastReport,
  resendBroadcastToUnread,
} from "./communication_service.ts";
import { BroadcastNotFoundError } from "./communication_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";

interface Captured {
  sql: string;
  args: unknown[];
}

function schoolClaims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u-admin",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions: ["sendBroadcast"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

/**
 * Fake db driven by a per-SQL-substring responder table. Any SQL that doesn't
 * match a responder returns [] (covers the audit INSERTs / idempotency SELECT,
 * which are fire-and-forget with no consumed result).
 */
function fakeDb(
  responders: { match: RegExp; rows: unknown[] }[],
): { db: TenantQueryClient; calls: Captured[] } {
  const calls: Captured[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, args: unknown[] = []): Promise<any[]> {
      calls.push({ sql, args });
      for (const r of responders) {
        if (r.match.test(sql)) return Promise.resolve(r.rows);
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

Deno.test("COM-1: getBroadcastReport returns summary + counts + unread roster", async () => {
  const { db, calls } = fakeDb([
    {
      match: /FROM comm_broadcasts/,
      rows: [{
        id: "bcast-1",
        title: "Holiday notice",
        audience: "all_parents",
        status: "sent",
        requires_ack: false,
        sent_at: "2026-07-02T10:00:00.000Z",
        scheduled_at: null,
      }],
    },
    {
      // aggregate FILTER counts: 5 total, 4 sent, 1 failed, 0 pending, 2 read,
      // 2 unread (sent & !read), 1 acknowledged (COM-D1).
      match: /count\(\*\) FILTER/,
      rows: [{ total: "5", sent: "4", failed: "1", pending: "0", read: "2", unread: "2", acknowledged: "1" }],
    },
    {
      match: /LEFT JOIN users/,
      rows: [
        { user_id: "u-2", name: "Asha Rao" },
        { user_id: "u-3", name: "Bhaskar N" },
      ],
    },
  ]);

  const report = await getBroadcastReport(db, schoolClaims(), "bcast-1");

  assertEquals(report.broadcast, {
    id: "bcast-1",
    title: "Holiday notice",
    audience: "all_parents",
    status: "sent",
    requiresAck: false,
    sentAt: "2026-07-02T10:00:00.000Z",
    scheduledAt: null,
  });
  assertEquals(report.counts, {
    total: 5,
    sent: 4,
    failed: 1,
    pending: 0,
    read: 2,
    unread: 2,
    acknowledged: 1,
  });
  assertEquals(report.unreadRecipients, [
    { userId: "u-2", name: "Asha Rao" },
    { userId: "u-3", name: "Bhaskar N" },
  ]);

  // The counts + unread roster are read from notification_deliveries, NOT
  // comm_recipients (which is the intended-audience record and stays 'pending').
  const countSql = calls.find((c) => /count\(\*\) FILTER/.test(c.sql))!;
  assert(countSql.sql.includes("FROM notification_deliveries"));
  assert(countSql.sql.includes("broadcast_id = $1"));
  assertEquals(countSql.args, ["bcast-1"]);
  const rosterSql = calls.find((c) => /LEFT JOIN users/.test(c.sql))!;
  assert(rosterSql.sql.includes("status = 'sent'"));
  assert(rosterSql.sql.includes("is_read = false"));
  assert(!calls.some((c) => c.sql.includes("comm_recipients")));
});

Deno.test("COM-1: getBroadcastReport throws BroadcastNotFoundError when not in scope", async () => {
  const { db } = fakeDb([{ match: /FROM comm_broadcasts/, rows: [] }]);
  await assertRejects(
    () => getBroadcastReport(db, schoolClaims(), "missing"),
    BroadcastNotFoundError,
  );
});

Deno.test("COM-1: getBroadcastReport requires school scope", async () => {
  const { db } = fakeDb([]);
  await assertRejects(
    () => getBroadcastReport(db, schoolClaims({ school_id: null }), "bcast-1"),
    Error,
    "School context required",
  );
});

Deno.test("COM-3: resendBroadcastToUnread re-enqueues ONLY unread and returns the count", async () => {
  const { db, calls } = fakeDb([
    {
      match: /SELECT \* FROM comm_broadcasts/,
      rows: [{
        id: "bcast-1",
        organization_id: "org-1",
        school_id: "school-1",
        audience: "all_parents",
        title: "Holiday notice",
        body: "School closed tomorrow",
        status: "sent",
        scheduled_at: null,
        sent_at: "2026-07-02T10:00:00.000Z",
        created_by: "u-admin",
        created_at: "2026-07-02T09:00:00.000Z",
      }],
    },
    {
      match: /SELECT DISTINCT recipient_user_id/,
      rows: [
        { recipient_user_id: "u-2" },
        { recipient_user_id: "u-3" },
      ],
    },
    {
      // enqueueDeliveriesBatch RETURNING id → one row per enqueued recipient.
      match: /INSERT INTO notification_deliveries/,
      rows: [{ id: "d-1" }, { id: "d-2" }],
    },
  ]);

  const result = await resendBroadcastToUnread(db, schoolClaims(), "bcast-1");
  assertEquals(result, { resent: 2 });

  // The re-enqueue targets exactly the unread ids, stamped with the broadcast_id.
  const enqueue = calls.find((c) => c.sql.includes("INSERT INTO notification_deliveries"))!;
  assert(enqueue.sql.includes("broadcast_id"));
  // Fixed params: org, school, channel, category, subject, body, route(null),
  // broadcast_id, requires_ack(false — resend keeps the original delivery flag
  // off; a resend is a nudge, not a new ack requirement), then one user id per
  // unread recipient.
  assertEquals(enqueue.args, [
    "org-1",
    "school-1",
    "push",
    "announcement",
    "Holiday notice",
    "School closed tomorrow",
    null,
    "bcast-1",
    false,
    "u-2",
    "u-3",
  ]);

  // The unread query is read off the delivery ledger.
  const unread = calls.find((c) => /SELECT DISTINCT recipient_user_id/.test(c.sql))!;
  assert(unread.sql.includes("FROM notification_deliveries"));
  assert(unread.sql.includes("status = 'sent'"));
  assert(unread.sql.includes("is_read = false"));
});

Deno.test("COM-3: resendBroadcastToUnread with 0 unread returns 0 and enqueues nothing", async () => {
  const { db, calls } = fakeDb([
    {
      match: /SELECT \* FROM comm_broadcasts/,
      rows: [{
        id: "bcast-1",
        organization_id: "org-1",
        school_id: "school-1",
        audience: "all_parents",
        title: "Holiday notice",
        body: "School closed tomorrow",
        status: "sent",
        scheduled_at: null,
        sent_at: "2026-07-02T10:00:00.000Z",
        created_by: "u-admin",
        created_at: "2026-07-02T09:00:00.000Z",
      }],
    },
    { match: /SELECT DISTINCT recipient_user_id/, rows: [] },
  ]);

  const result = await resendBroadcastToUnread(db, schoolClaims(), "bcast-1");
  assertEquals(result, { resent: 0 });
  // No delivery INSERT and no audit write when there is nothing to resend.
  assert(!calls.some((c) => c.sql.includes("INSERT INTO notification_deliveries")));
  assert(!calls.some((c) => c.sql.includes("INSERT INTO audit_events")));
});

Deno.test("COM-3: resendBroadcastToUnread throws BroadcastNotFoundError when not in scope", async () => {
  const { db } = fakeDb([{ match: /SELECT \* FROM comm_broadcasts/, rows: [] }]);
  await assertRejects(
    () => resendBroadcastToUnread(db, schoolClaims(), "missing"),
    BroadcastNotFoundError,
  );
});
