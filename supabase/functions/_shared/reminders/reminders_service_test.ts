// XCT-2: the shared in-app reminder / scheduling rail.
//
// DB-free coverage against a capturing fake TenantQueryClient (same fake-db
// pattern as communication/broadcast_batch_test.ts). Proves the done-when:
// ≥1 in-app reminder FIRES end-to-end through the rail — a due reminder is
// claimed, fanned out to its audience, and enqueued as a PENDING in-app
// delivery (what the notifications inbox surfaces), and the source row is
// finalized. Also pins the authoring seam (validation + delegation) and that
// there is literally ONE runner shared with the scheduled-broadcast path.

import {
  assert,
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  runDueReminders,
  scheduleReminder,
} from "./reminders_service.ts";
import {
  CommunicationValidationError,
  runDueScheduledBroadcasts,
} from "../communication/communication_service.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";

interface Captured {
  sql: string;
  args: unknown[];
}

function fakeDb(
  responders: { match: RegExp; rows: unknown[] }[] = [],
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

function schoolClaims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u-admin",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions: ["sendBroadcast", "viewCommunications"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

const dueBroadcastRow = {
  id: "rem-due",
  organization_id: "org-1",
  school_id: "school-1",
  audience: "all_teachers",
  audience_class: null,
  audience_section: null,
  title: "Fees due tomorrow",
  body: "Term 2 fees are due tomorrow.",
  status: "sending",
  requires_ack: false,
  scheduled_at: "2026-07-04T09:00:00.000Z",
  sent_at: null,
  created_by: "u-admin",
  created_at: "2026-07-01T00:00:00.000Z",
};

Deno.test("XCT-2: a DUE reminder fires end-to-end into a pending in-app delivery", async () => {
  const { db, calls } = fakeDb([
    // claim the due reminder (scheduled → sending)
    { match: /SET status = 'sending'/, rows: [dueBroadcastRow] },
    // resolve the all_teachers audience NOW
    { match: /FROM school_memberships/, rows: [{ user_id: "u1" }, { user_id: "u2" }] },
    // the fan-out enqueues one pending in-app delivery per recipient
    { match: /INSERT INTO notification_deliveries/, rows: [{ id: "d1" }, { id: "d2" }] },
  ]);

  const result = await runDueReminders(db, schoolClaims());

  // The reminder fired: one broadcast dispatched to two recipients.
  assertEquals(result.processed, 1);
  assertEquals(result.broadcastIds, ["rem-due"]);
  assertEquals(result.totalRecipients, 2);

  // It landed as a PENDING in-app delivery (what the notifications inbox reads).
  const enqueue = calls.find((c) =>
    c.sql.includes("INSERT INTO notification_deliveries")
  );
  assert(enqueue, "a notification delivery must be enqueued");
  assert(enqueue!.sql.includes("'pending'"));
  // Carries the reminder's title + ties back to the source row (COM-1).
  assert(enqueue!.args.includes("Fees due tomorrow"));
  assert(enqueue!.args.includes("rem-due"));

  // The source row is finalized so it can never re-fire.
  const finalize = calls.find((c) => /SET status = 'sent'/.test(c.sql));
  assert(finalize, "the reminder row must be finalized to 'sent'");
  assertEquals(finalize!.args, ["rem-due"]);
});

Deno.test("XCT-2: nothing due → the rail fires no reminder and enqueues nothing", async () => {
  const { db, calls } = fakeDb([
    { match: /SET status = 'sending'/, rows: [] }, // no due rows claimed
  ]);

  const result = await runDueReminders(db, schoolClaims());

  assertEquals(result.processed, 0);
  assertEquals(result.broadcastIds, []);
  assertEquals(result.totalRecipients, 0);
  assert(
    !calls.some((c) => c.sql.includes("INSERT INTO notification_deliveries")),
    "a future reminder must NOT fire early",
  );
});

Deno.test("XCT-2: there is exactly ONE runner (reminder rail === scheduled-broadcast runner)", () => {
  assert(
    runDueReminders === runDueScheduledBroadcasts,
    "reminders must reuse the single scheduled runner, not fork it",
  );
});

Deno.test("XCT-2: scheduleReminder persists a scheduled row and normalizes remindAt", async () => {
  const { db, calls } = fakeDb([
    {
      match: /INSERT INTO comm_broadcasts/,
      rows: [{ ...dueBroadcastRow, status: "scheduled" }],
    },
  ]);

  const result = await scheduleReminder(db, schoolClaims(), {
    audience: "all_teachers",
    title: "Fees due tomorrow",
    body: "Term 2 fees are due tomorrow.",
    remindAt: "2026-07-04T09:00:00Z",
  });

  assertEquals(result.status, "scheduled");
  assertEquals(result.scheduledAt, "2026-07-04T09:00:00.000Z");
  const insert = calls.find((c) => c.sql.includes("INSERT INTO comm_broadcasts"));
  assert(insert, "a scheduled reminder row must be inserted");
  assert(insert!.sql.includes("'scheduled'"));
  // The schedule is audited (durable trail).
  assert(calls.some((c) => c.sql.includes("INSERT INTO audit_events")));
});

Deno.test("XCT-2: scheduleReminder rejects an empty / unparseable remindAt (422)", async () => {
  const { db, calls } = fakeDb();
  await assertRejects(
    () =>
      scheduleReminder(db, schoolClaims(), {
        audience: "all_teachers",
        title: "t",
        body: "b",
        remindAt: "",
      }),
    CommunicationValidationError,
  );
  await assertRejects(
    () =>
      scheduleReminder(db, schoolClaims(), {
        audience: "all_teachers",
        title: "t",
        body: "b",
        remindAt: "not-a-date",
      }),
    CommunicationValidationError,
  );
  // A bad payload must never insert a row.
  assert(!calls.some((c) => c.sql.includes("INSERT INTO comm_broadcasts")));
});
