// INV-7 — low-stock alert rides the shared XCT-2 reminder rail.
//
// DB-free unit coverage against a capturing fake TenantQueryClient (same
// pattern as communication_audience_ack_test.ts). Pins:
//   • the alert is SCHEDULED (status='scheduled' comm_broadcasts row) for the
//     'storekeepers' audience with the fixed title — never an immediate
//     'sending' broadcast, never all_staff,
//   • idempotency: a still-pending scheduled low-stock reminder for the school
//     suppresses a duplicate,
//   • error isolation: a scheduling failure rolls back ONLY the reminder
//     savepoint and never throws (the posted stock issue can't be failed by it),
//   • the storekeepers audience resolver targets role='storekeeper' memberships
//     and falls back to the all-staff set when the school has none,
//   • normalizeBroadcastAudience passes the token through (+ singular alias),
//   • migration 20260851 widens the audience CHECK (storekeepers + restores
//     all_staff) and seeds the storekeeper role.
//
// GOVERNANCE TRIPWIRE: nothing here touches stock math / ledger / maker-checker
// — those invariants stay pinned by inventory_stock_repository_test.ts.

import { assert, assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  LOW_STOCK_REMINDER_TITLE,
  scheduleLowStockReminderIfNeeded,
} from "./inventory_stock_handlers.ts";
import { resolveBroadcastRecipients } from "../communication/communication_repository.ts";
import { normalizeBroadcastAudience } from "../communication/communication_service.ts";

interface Captured {
  sql: string;
  args: unknown[];
}

function fakeDb(
  responders: { match: RegExp; rows?: unknown[]; throws?: Error }[] = [],
): { db: TenantQueryClient; calls: Captured[] } {
  const calls: Captured[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, args: unknown[] = []): Promise<any[]> {
      calls.push({ sql, args });
      for (const r of responders) {
        if (r.match.test(sql)) {
          if (r.throws) return Promise.reject(r.throws);
          return Promise.resolve(r.rows ?? []);
        }
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

function claims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u-store",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "storekeeper",
    role_slugs: ["storekeeper"],
    primary_role: "storekeeper",
    permissions: ["viewInventory", "manageInventory"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  } as AccessTokenClaims;
}

const scheduledRow = {
  id: "bcast-1",
  audience: "storekeepers",
  audience_class: null,
  audience_section: null,
  requires_ack: false,
  title: LOW_STOCK_REMINDER_TITLE,
  body: "3 item(s) are at or below their reorder level.",
  status: "scheduled",
  scheduled_at: "2026-07-06T00:00:00.000Z",
};

Deno.test("INV-7: schedules ONE storekeepers reminder on the XCT-2 rail (status='scheduled')", async () => {
  const { db, calls } = fakeDb([
    { match: /SELECT id FROM comm_broadcasts/, rows: [] },
    { match: /INSERT INTO comm_broadcasts/, rows: [scheduledRow] },
  ]);
  const result = await scheduleLowStockReminderIfNeeded(db, claims(), {
    issueId: "issue-1",
    lowStockCount: 3,
  });
  assertEquals(result.scheduled, true);

  // Persisted via the scheduled-broadcast substrate, NOT the immediate path.
  const insert = calls.find((c) => c.sql.includes("INSERT INTO comm_broadcasts"))!;
  assert(insert.sql.includes("'scheduled'"), "must persist a scheduled row");
  assert(insert.sql.includes("scheduled_at"));
  assertEquals(insert.args[2], "storekeepers"); // audience
  assertEquals(insert.args[6], LOW_STOCK_REMINDER_TITLE); // title
  assert(String(insert.args[7]).includes("3 item(s)")); // digest body

  // No immediate fan-out at issue time: recipients resolve at FIRE time.
  assert(!calls.some((c) => c.sql.includes("INSERT INTO comm_recipients")));
  assert(!calls.some((c) => c.sql.includes("INSERT INTO notification_deliveries")));

  // Wrapped in the reminder savepoint and released on success.
  assertEquals(calls[0].sql, "SAVEPOINT inv7_low_stock_reminder");
  assert(calls.some((c) => c.sql === "RELEASE SAVEPOINT inv7_low_stock_reminder"));

  // Audited.
  assert(calls.some((c) => c.sql.includes("INSERT INTO audit_events")));
});

Deno.test("INV-7: idempotency — a pending scheduled low-stock reminder suppresses a duplicate", async () => {
  const { db, calls } = fakeDb([
    { match: /SELECT id FROM comm_broadcasts/, rows: [{ id: "bcast-pending" }] },
  ]);
  const result = await scheduleLowStockReminderIfNeeded(db, claims(), {
    issueId: "issue-2",
    lowStockCount: 5,
  });
  assertEquals(result.scheduled, false);
  // Probe is scoped to org + school + audience + fixed title + status.
  const probe = calls.find((c) => c.sql.includes("SELECT id FROM comm_broadcasts"))!;
  assert(probe.sql.includes("audience = 'storekeepers'"));
  assert(probe.sql.includes("status = 'scheduled'"));
  assertEquals(probe.args, ["org-1", "school-1", LOW_STOCK_REMINDER_TITLE]);
  // Nothing scheduled, nothing audited.
  assert(!calls.some((c) => c.sql.includes("INSERT INTO comm_broadcasts")));
  assert(!calls.some((c) => c.sql.includes("INSERT INTO audit_events")));
});

Deno.test("INV-7: a scheduling failure NEVER throws — savepoint rolls back only the reminder", async () => {
  const { db, calls } = fakeDb([
    { match: /SELECT id FROM comm_broadcasts/, rows: [] },
    { match: /INSERT INTO comm_broadcasts/, throws: new Error("audience CHECK violation") },
  ]);
  const result = await scheduleLowStockReminderIfNeeded(db, claims(), {
    issueId: "issue-3",
    lowStockCount: 2,
  });
  assertEquals(result.scheduled, false);
  assert(calls.some((c) => c.sql === "ROLLBACK TO SAVEPOINT inv7_low_stock_reminder"));
  assert(!calls.some((c) => c.sql === "RELEASE SAVEPOINT inv7_low_stock_reminder"));
});

Deno.test("INV-7: zero low-stock rows → no reminder work at all", async () => {
  const { db, calls } = fakeDb();
  const result = await scheduleLowStockReminderIfNeeded(db, claims(), {
    issueId: "issue-4",
    lowStockCount: 0,
  });
  assertEquals(result.scheduled, false);
  assertEquals(calls.length, 0);
});

// ── storekeepers audience: resolver + normalization ──────────────────────────

Deno.test("INV-7: storekeepers resolver targets role='storekeeper' active memberships", async () => {
  const { db, calls } = fakeDb([
    { match: /role = 'storekeeper'/, rows: [{ user_id: "u-sk-1" }, { user_id: "u-sk-2" }] },
  ]);
  const ids = await resolveBroadcastRecipients(db, "org-1", "school-1", "storekeepers");
  assertEquals(ids, ["u-sk-1", "u-sk-2"]);
  const q = calls.find((c) => /role = 'storekeeper'/.test(c.sql))!;
  assert(q.sql.includes("FROM school_memberships"));
  assert(q.sql.includes("status = 'active'"));
  assertEquals(q.args, ["school-1"]);
  // Targeted hit → no all-staff fallback query.
  assertEquals(calls.length, 1);
});

Deno.test("INV-7: storekeepers resolver falls back to the all-staff set when none exist", async () => {
  const { db, calls } = fakeDb([
    { match: /role = 'storekeeper'/, rows: [] },
    { match: /FROM school_memberships\s+WHERE school_id = \$1 AND status = 'active'/, rows: [{ user_id: "u-staff-1" }] },
  ]);
  const ids = await resolveBroadcastRecipients(db, "org-1", "school-1", "storekeepers");
  assertEquals(ids, ["u-staff-1"]);
  assertEquals(calls.length, 2);
  // The fallback is the same shape as the all_staff branch (no role filter).
  assert(!calls[1].sql.includes("role ="));
});

Deno.test("INV-7: normalizeBroadcastAudience passes 'storekeepers' through (+ singular alias)", () => {
  assertEquals(normalizeBroadcastAudience("storekeepers"), "storekeepers");
  assertEquals(normalizeBroadcastAudience("storekeeper"), "storekeepers");
});

// ── migration 20260851: audience CHECK + role seed ────────────────────────────

Deno.test("INV-7 migration: widens the audience CHECK (storekeepers, all_staff restored) + seeds the role", async () => {
  const sql = await Deno.readTextFile(
    new URL(
      "../../../migrations/20260851000000_communication_storekeepers_audience.sql",
      import.meta.url,
    ),
  );
  assertEquals(sql.includes("DROP CONSTRAINT IF EXISTS comm_broadcasts_audience_check"), true);
  assertEquals(sql.includes("'storekeepers'"), true);
  // 20260838000000's re-add dropped 'all_staff' (added by 20260729000000); this
  // re-add must restore it so existing all_staff broadcasts stay valid.
  assertEquals(sql.includes("'all_staff'"), true);
  assertEquals(sql.includes("'class_parents'"), true);
  // Role seed is idempotent and grants only catalogued permissions.
  assertEquals(sql.includes("('storekeeper', 'Storekeeper', 'school')"), true);
  assertEquals(sql.includes("ON CONFLICT (slug) DO NOTHING"), true);
  assertEquals(sql.includes("ON CONFLICT (role_slug, permission_slug) DO NOTHING"), true);
});
