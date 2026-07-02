// PERF-1 (Wave 4): broadcast fan-out writes recipients and push deliveries as
// single multi-row INSERTs instead of one round-trip per recipient. These tests
// pin the generated SQL shape (one placeholder group per recipient, no per-row
// query) against a capturing fake db.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  enqueueDeliveriesBatch,
  insertBroadcastRecipientsBatch,
} from "./communication_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

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
