// PERF-1 (Wave 4): broadcast fan-out writes recipients and push deliveries as
// single multi-row INSERTs instead of one round-trip per recipient. These tests
// pin the generated SQL shape (one placeholder group per recipient, no per-row
// query) against a capturing fake db.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  enqueueDeliveriesBatch,
  insertBroadcastRecipientsBatch,
} from "./communication_repository.ts";
import {
  runDueScheduledBroadcasts,
  sendBroadcastMessage,
} from "./communication_service.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";

interface Captured {
  sql: string;
  args: unknown[];
}

function fakeDb(): { db: TenantQueryClient; calls: Captured[] } {
  const calls: Captured[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, args: unknown[] = []): Promise<any[]> {
      calls.push({ sql, args });
      // enqueueDeliveriesBatch reads rows.length to count queued rows: return one
      // row per recipient (args beyond the 9 fixed params — incl. route (NOT-1),
      // broadcast_id (COM-1) and requires_ack (COM-D1)).
      const recipientCount = Math.max(0, args.length - 9);
      return Promise.resolve(
        Array.from({ length: recipientCount }, (_, i) => ({ id: `d-${i}` })),
      );
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

Deno.test("insertBroadcastRecipientsBatch issues one multi-row INSERT", async () => {
  const { db, calls } = fakeDb();
  await insertBroadcastRecipientsBatch(db, "bcast", "org", ["u1", "u2", "u3"]);

  assertEquals(calls.length, 1); // not one query per recipient
  const { sql, args } = calls[0];
  assert(sql.includes("INSERT INTO comm_recipients"));
  assert(sql.includes("ON CONFLICT"));
  // ($1,$2 fixed) + one positional user param each.
  assertEquals(args, ["bcast", "org", "u1", "u2", "u3"]);
  assertEquals((sql.match(/\$\d+/g) ?? []).filter((p) => p === "$3").length, 1);
});

Deno.test("insertBroadcastRecipientsBatch no-ops on empty cohort", async () => {
  const { db, calls } = fakeDb();
  await insertBroadcastRecipientsBatch(db, "bcast", "org", []);
  assertEquals(calls.length, 0);
});

Deno.test("enqueueDeliveriesBatch issues one multi-row INSERT and counts rows", async () => {
  const { db, calls } = fakeDb();
  const queued = await enqueueDeliveriesBatch(db, {
    organizationId: "org",
    schoolId: "school",
    recipientUserIds: ["u1", "u2"],
    channel: "push",
    category: "announcement",
    renderedSubject: "Title",
    renderedBody: "Body",
  });

  assertEquals(queued, 2);
  assertEquals(calls.length, 1);
  const { sql, args } = calls[0];
  assert(sql.includes("INSERT INTO notification_deliveries"));
  assert(sql.includes("'pending'"));
  // 9 fixed params (route NULL when unset — NOT-1; broadcast_id NULL when unset —
  // COM-1; requires_ack false when unset — COM-D1), then one user param per
  // recipient.
  assertEquals(
    args,
    ["org", "school", "push", "announcement", "Title", "Body", null, null, false, "u1", "u2"],
  );
});

Deno.test("enqueueDeliveriesBatch carries the deep-link route when set (NOT-1)", async () => {
  const { db, calls } = fakeDb();
  await enqueueDeliveriesBatch(db, {
    organizationId: "org",
    schoolId: "school",
    recipientUserIds: ["u1"],
    channel: "push",
    category: "announcement",
    renderedSubject: "Title",
    renderedBody: "Body",
    route: "/parent/notices",
  });
  const { sql, args } = calls[0];
  assert(sql.includes("route"));
  // route is the 7th fixed param, broadcast_id the 8th (NULL here), requires_ack
  // the 9th (false here), before the per-recipient user ids.
  assertEquals(args, ["org", "school", "push", "announcement", "Title", "Body", "/parent/notices", null, false, "u1"]);
});

Deno.test("enqueueDeliveriesBatch stamps the broadcast_id when set (COM-1)", async () => {
  const { db, calls } = fakeDb();
  await enqueueDeliveriesBatch(db, {
    organizationId: "org",
    schoolId: "school",
    recipientUserIds: ["u1"],
    channel: "push",
    category: "announcement",
    renderedSubject: "Title",
    renderedBody: "Body",
    broadcastId: "bcast-1",
  });
  const { sql, args } = calls[0];
  assert(sql.includes("broadcast_id"));
  // broadcast_id is the 8th fixed param, requires_ack the 9th (false here),
  // before the per-recipient user ids.
  assertEquals(
    args,
    ["org", "school", "push", "announcement", "Title", "Body", null, "bcast-1", false, "u1"],
  );
});

Deno.test("enqueueDeliveriesBatch no-ops on empty cohort", async () => {
  const { db, calls } = fakeDb();
  const queued = await enqueueDeliveriesBatch(db, {
    organizationId: "org",
    schoolId: "school",
    recipientUserIds: [],
    channel: "push",
    category: "announcement",
    renderedSubject: "Title",
    renderedBody: "Body",
  });
  assertEquals(queued, 0);
  assertEquals(calls.length, 0);
});

// ── ICA-C6 (P1): a > 5,000-recipient broadcast must reach EVERYONE ────────────
// REGRESSION: the fan-out previously did `resolved.slice(0, 5000)`, silently
// DROPPING every recipient past the 5,000th with no error/continuation. The fix
// chunks the FULL cohort into successive bounded multi-row INSERTs, so a
// larger-than-a-batch audience is fully enqueued while each INSERT stays bounded.
// These drive the two service entry points (immediate send + scheduled dispatch)
// against a responder-dispatching fake db and prove: nothing is dropped, the
// past-cap tail recipient IS enqueued, and each INSERT stays within one batch.

// A 5,001-strong cohort: one past the historical 5,000 cap, so the 5,001st
// recipient ("u-5000") is exactly the row that used to be silently dropped.
const BIG_COHORT = 5001;

interface Captured {
  sql: string;
  args: unknown[];
}

/** Responder-dispatching fake db (same in-file pattern as
 * communication_audience_ack_test.ts): first matching regex wins, else []. */
function responderDb(
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
  } as AccessTokenClaims;
}

// One row per teacher recipient — `all_teachers` resolves via school_memberships.
const bigRoster = Array.from(
  { length: BIG_COHORT },
  (_, i) => ({ user_id: `u-${i}` }),
);

/** All recipient user-ids enqueued into notification_deliveries across every
 * chunk. Each delivery INSERT is `9 fixed params + one user id per recipient`. */
function enqueuedRecipients(calls: Captured[]): string[] {
  return calls
    .filter((c) => c.sql.includes("INSERT INTO notification_deliveries"))
    .flatMap((c) => c.args.slice(9) as string[]);
}

/** All recipient user-ids written to the comm_recipients ledger across every
 * chunk. Each ledger INSERT is `2 fixed params + one user id per recipient`. */
function ledgerRecipients(calls: Captured[]): string[] {
  return calls
    .filter((c) => c.sql.includes("INSERT INTO comm_recipients"))
    .flatMap((c) => c.args.slice(2) as string[]);
}

Deno.test("ICA-C6: immediate broadcast of >5,000 recipients enqueues EVERYONE (no silent truncation)", async () => {
  const { db, calls } = responderDb([
    {
      match: /INSERT INTO comm_broadcasts/,
      rows: [{
        id: "bcast-big",
        audience: "all_teachers",
        audience_class: null,
        audience_section: null,
        requires_ack: false,
        title: "All-staff notice",
        body: "Body",
        status: "sending",
      }],
    },
    // resolveBroadcastRecipients(all_teachers) → school_memberships
    { match: /FROM school_memberships/, rows: bigRoster },
  ]);

  const res = await sendBroadcastMessage(db, schoolClaims(), {
    audience: "all_teachers",
    title: "All-staff notice",
    body: "Body",
  }) as { recipientCount: number; droppedOverCap: number };

  // Response counts: the full cohort is queued, nothing dropped over a cap.
  assertEquals(res.recipientCount, BIG_COHORT);
  assertEquals(res.droppedOverCap, 0);

  // Every recipient — including the historically-dropped 5,001st ("u-5000") — is
  // both ledgered and enqueued for delivery. De-duped set size proves no loss.
  const enqueued = enqueuedRecipients(calls);
  const ledgered = ledgerRecipients(calls);
  assertEquals(enqueued.length, BIG_COHORT);
  assertEquals(new Set(enqueued).size, BIG_COHORT);
  assertEquals(ledgered.length, BIG_COHORT);
  assert(enqueued.includes("u-5000"), "the past-cap tail recipient must be enqueued, not dropped");
  assert(ledgered.includes("u-5000"), "the past-cap tail recipient must be ledgered, not dropped");

  // Per-statement efficiency is preserved: the cohort is chunked over MORE THAN
  // ONE bounded INSERT (not one giant statement, not one query per recipient),
  // and no single delivery/ledger INSERT exceeds one batch (5,000 rows).
  const deliveryInserts = calls.filter((c) => c.sql.includes("INSERT INTO notification_deliveries"));
  const ledgerInserts = calls.filter((c) => c.sql.includes("INSERT INTO comm_recipients"));
  assert(deliveryInserts.length >= 2, "cohort past one batch must span multiple INSERTs");
  assert(ledgerInserts.length >= 2, "cohort past one batch must span multiple ledger INSERTs");
  for (const c of deliveryInserts) {
    assert((c.args.length - 9) <= 5000, "each delivery INSERT must stay within one batch");
    assert((c.args.length - 9) >= 1, "no empty delivery INSERT");
  }
  for (const c of ledgerInserts) {
    assert((c.args.length - 2) <= 5000, "each ledger INSERT must stay within one batch");
  }
});

Deno.test("ICA-C6: scheduled dispatch of >5,000 recipients enqueues EVERYONE (second entry point)", async () => {
  const { db, calls } = responderDb([
    // claimDueScheduledBroadcasts → UPDATE ... SET status = 'sending' RETURNING *
    {
      match: /SET status = 'sending'/,
      rows: [{
        id: "bcast-sched-big",
        organization_id: "org-1",
        school_id: "school-1",
        audience: "all_teachers",
        audience_class: null,
        audience_section: null,
        requires_ack: false,
        title: "Scheduled all-staff notice",
        body: "Body",
        status: "sending",
        scheduled_at: "2026-07-01T00:00:00.000Z",
      }],
    },
    { match: /FROM school_memberships/, rows: bigRoster },
  ]);

  const res = await runDueScheduledBroadcasts(db, schoolClaims()) as {
    processed: number;
    totalRecipients: number;
  };

  // The runner dispatched the one due broadcast to its FULL current audience.
  assertEquals(res.processed, 1);
  assertEquals(res.totalRecipients, BIG_COHORT);

  const enqueued = enqueuedRecipients(calls);
  assertEquals(enqueued.length, BIG_COHORT);
  assertEquals(new Set(enqueued).size, BIG_COHORT);
  assert(enqueued.includes("u-5000"), "the past-cap tail recipient must be dispatched, not dropped");

  // Bounded, chunked fan-out preserved on the scheduled path too.
  const deliveryInserts = calls.filter((c) => c.sql.includes("INSERT INTO notification_deliveries"));
  assert(deliveryInserts.length >= 2, "scheduled cohort past one batch must span multiple INSERTs");
  for (const c of deliveryInserts) {
    assert((c.args.length - 9) <= 5000, "each scheduled delivery INSERT must stay within one batch");
  }
});
