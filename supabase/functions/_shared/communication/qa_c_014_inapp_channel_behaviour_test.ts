// QA-C-014 — In-App channel BEHAVIOUR certification (server / repository leg).
//
// The in-app inbox is the durable channel: every enqueued delivery lands in
// `notification_deliveries` and is read back + mutated through the repository.
// This cert pins the DB-free contract of those three repository functions
// against a capturing fake `TenantQueryClient` (the same idiom as
// broadcast_batch_test.ts) — NO live DB:
//
//   list (render)   → listDeliveriesForUser scopes to org + recipient and only
//                     surfaces 'sent'/'pending' rows (read-but-not-archived),
//                     newest-first — the rows the inbox renders,
//   mark-read       → markNotificationRead flips is_read for THAT user's row only
//                     and reports whether a row was actually updated (idempotent,
//                     tenant-scoped); markAllNotificationsRead returns the count
//                     of rows it changed,
//   audit           → each mutation is scoped by organization_id + recipient and
//                     bumps updated_at, so the read state is a durable, auditable
//                     change on the row (not client-only).
//
// KNOWN GAP (documented — NOT built here): the in-app channel has NO
// per-notification deep-link ROUTE on the inbox row. The DB row DOES carry a
// `route` column (push uses it), and the client model AppNotification has NO
// `route`/`deepLink` field, so tapping an inbox row marks it read but cannot
// navigate to the source surface. This is asserted/noted honestly below and in
// the Flutter cert; wiring it is a tracked follow-up, not part of this row.
//
// INFRA-BLOCKED: none for this server leg — the repository functions are pure
// SQL builders certified against the fake client. (The CLIENT render + tap is
// covered by test/features/notifications/qw4_notifications_persistence_test.dart
// and qw3_notifications_interaction_widget_test.dart.)

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  listDeliveriesForUser,
  markAllNotificationsRead,
  markNotificationRead,
  type NotificationDeliveryRow,
} from "./communication_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

const ORG = "org-1";
const USER = "11111111-1111-4111-8111-111111111111";

interface Captured {
  sql: string;
  args: unknown[];
}

/**
 * Capturing fake client. `rows` is what the next queryObject resolves with, so a
 * test can model "1 row updated" vs "no row matched".
 */
function fakeDb(
  rows: Record<string, unknown>[] = [],
): { db: TenantQueryClient; calls: Captured[] } {
  const calls: Captured[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, args: unknown[] = []): Promise<any[]> {
      calls.push({ sql, args });
      return Promise.resolve(rows);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

// --- list (render): scope + status filter + ordering -------------------------

Deno.test("QA-C-014 listDeliveriesForUser renders only this user's sent/pending rows, newest first", async () => {
  const sample: Partial<NotificationDeliveryRow>[] = [
    { id: "d1", recipient_user_id: USER, status: "sent", is_read: false, route: "/parent/fees" },
    { id: "d2", recipient_user_id: USER, status: "pending", is_read: true, route: null },
  ];
  const { db, calls } = fakeDb(sample as Record<string, unknown>[]);
  const rows = await listDeliveriesForUser(db, ORG, USER, 50, 0);

  assertEquals(rows.length, 2);
  const { sql, args } = calls[0];
  // tenant + recipient scoped
  assert(sql.includes("organization_id = $1"));
  assert(sql.includes("recipient_user_id = $2"));
  // inbox only shows deliverable rows (sent/pending), never failed/archived noise
  assert(sql.includes("status IN ('sent', 'pending')"));
  // newest-first render order + pagination
  assert(sql.includes("ORDER BY created_at DESC"));
  assert(sql.includes("LIMIT $3 OFFSET $4"));
  assertEquals(args, [ORG, USER, 50, 0]);
});

// --- mark-read: per-row persist, tenant-scoped, idempotent -------------------

Deno.test("QA-C-014 markNotificationRead persists is_read for the user's row and reports success", async () => {
  // one row returned ⇒ a delivery was actually flipped to read.
  const { db, calls } = fakeDb([{ id: "d1" }]);
  const changed = await markNotificationRead(db, ORG, USER, "d1");

  assertEquals(changed, true);
  const { sql, args } = calls[0];
  assert(sql.includes("UPDATE notification_deliveries"));
  assert(sql.includes("is_read = true"));
  assert(sql.includes("updated_at = timezone('utc', now())")); // auditable change
  // mutation is scoped to org + recipient + the specific id (no cross-user mark).
  assert(sql.includes("organization_id = $1"));
  assert(sql.includes("recipient_user_id = $2"));
  assert(sql.includes("id = $3"));
  assertEquals(args, [ORG, USER, "d1"]);
});

Deno.test("QA-C-014 markNotificationRead reports false when no row matched (idempotent / not-mine)", async () => {
  const { db } = fakeDb([]); // id not visible to this user / already gone
  const changed = await markNotificationRead(db, ORG, USER, "not-mine");
  assertEquals(changed, false);
});

Deno.test("QA-C-014 markAllNotificationsRead flips only this user's unread rows and counts them", async () => {
  const { db, calls } = fakeDb([{ id: "d1" }, { id: "d2" }, { id: "d3" }]);
  const count = await markAllNotificationsRead(db, ORG, USER);

  assertEquals(count, 3); // returns the number of rows actually changed
  const { sql, args } = calls[0];
  assert(sql.includes("UPDATE notification_deliveries"));
  assert(sql.includes("is_read = true"));
  assert(sql.includes("is_read = false")); // only currently-unread rows are touched
  assert(sql.includes("organization_id = $1"));
  assert(sql.includes("recipient_user_id = $2"));
  assertEquals(args, [ORG, USER]);
});

// --- KNOWN GAP: row carries a route column server-side, but the inbox tap does
//     not deep-link (no route on the client AppNotification model) -------------

Deno.test("QA-C-014 KNOWN GAP: delivery row has a route column but in-app tap does not deep-link", () => {
  // The DB row type DOES expose `route` (push reads it for the tray-tap deep
  // link). The in-app inbox, however, does not surface a per-notification route
  // to the client model, so tapping an inbox row only marks it read. This test
  // documents that the server-side field EXISTS (so wiring it later is a client
  // change, not a schema change) while the channel behaviour gap remains open.
  const row: Partial<NotificationDeliveryRow> = {
    id: "d1",
    recipient_user_id: USER,
    status: "sent",
    route: "/parent/fees",
    is_read: false,
  };
  assertEquals(row.route, "/parent/fees"); // server-side route is present...
  // ...but listDeliveriesForUser returns the whole row; the gap is that the
  // CLIENT model drops it (asserted in the Flutter cert). Noted, not fixed.
  assert("route" in row);
});
