// C1 · FIN-R2 (telecaller call queue) — the recovery CRM previously had NO
// unit coverage (only route-contract RBAC). These pin the NEW call-queue
// ranking (a pure, deterministic "who to call next" order) + its row mapping,
// and the call-queue query shape against a capturing fake db.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  callQueueEntryToApi,
  callQueuePriority,
  callQueueReason,
  type CallQueueSignals,
} from "./finance_recovery_handlers.ts";
import { type CallQueueRow, listCallQueue } from "./finance_recovery_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

const TODAY = "2026-07-04";

function signals(over: Partial<CallQueueSignals> = {}): CallQueueSignals {
  return {
    daysOverdue: 10,
    hasBrokenPromise: false,
    pendingPromiseDate: null,
    lastContactAt: null,
    today: TODAY,
    ...over,
  };
}

Deno.test("FIN-R2: a broken promise is the top call priority (0)", () => {
  const s = signals({ hasBrokenPromise: true, pendingPromiseDate: "2026-07-10" });
  assertEquals(callQueuePriority(s), 0);
  assertEquals(callQueueReason(s), "Promise broken — follow up");
});

Deno.test("FIN-R2: a promise due today/overdue ranks 1", () => {
  assertEquals(callQueuePriority(signals({ pendingPromiseDate: TODAY })), 1);
  assertEquals(callQueuePriority(signals({ pendingPromiseDate: "2026-07-01" })), 1);
  assertEquals(
    callQueueReason(signals({ pendingPromiseDate: TODAY })),
    "Promise due — confirm payment",
  );
});

Deno.test("FIN-R2: a FUTURE promise is de-prioritised (5) — leave them alone", () => {
  const s = signals({ pendingPromiseDate: "2026-07-20" });
  assertEquals(callQueuePriority(s), 5);
  assertEquals(callQueueReason(s), "Promised — awaiting date");
});

Deno.test("FIN-R2: never-contacted + overdue ranks 2, never-contacted + current ranks 4", () => {
  assertEquals(callQueuePriority(signals({ lastContactAt: null, daysOverdue: 10 })), 2);
  assertEquals(callQueueReason(signals({ lastContactAt: null, daysOverdue: 10 })), "Not yet contacted");
  assertEquals(callQueuePriority(signals({ lastContactAt: null, daysOverdue: 0 })), 4);
});

Deno.test("FIN-R2: stale contact (7+ days) ranks 3; recent contact ranks 4", () => {
  assertEquals(
    callQueuePriority(signals({ lastContactAt: "2026-06-20T09:00:00Z" })),
    3,
  );
  assertEquals(
    callQueueReason(signals({ lastContactAt: "2026-06-20T09:00:00Z" })),
    "No contact in 7+ days",
  );
  assertEquals(
    callQueuePriority(signals({ lastContactAt: "2026-07-03T09:00:00Z" })),
    4,
  );
  assertEquals(
    callQueueReason(signals({ lastContactAt: "2026-07-03T09:00:00Z" })),
    "Recently contacted",
  );
});

Deno.test("FIN-R2: callQueueEntryToApi maps a row and applies the ranking", () => {
  const row: CallQueueRow = {
    student_id: "stu-1",
    student_name: "Ravi Kumar",
    admission_number: "ADM-9",
    class_label: "8-A",
    outstanding: "4200",
    fee_account_id: "acc-1",
    days_overdue: "35",
    guardian_phone: "+919000000000",
    last_contact_at: null,
    pending_promise_date: null,
    has_broken_promise: true,
  };
  const api = callQueueEntryToApi(row, TODAY);
  assertEquals(api.studentId, "stu-1");
  assertEquals(api.studentName, "Ravi Kumar");
  assertEquals(api.admissionNumber, "ADM-9");
  assertEquals(api.outstanding, "4200");
  assertEquals(api.daysOverdue, 35);
  assertEquals(api.guardianPhone, "+919000000000");
  assertEquals(api.hasBrokenPromise, true);
  assertEquals(api.priority, 0); // broken promise
  assertEquals(api.reason, "Promise broken — follow up");
  assertEquals(api.lastContact, ""); // null → ""
  assertEquals(api.pendingPromiseDate, "");
});

Deno.test("FIN-R2: listCallQueue queries the defaulter accounts + recovery signals", async () => {
  const calls: { sql: string; args: unknown[] }[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, args: unknown[] = []): Promise<any[]> {
      calls.push({ sql, args });
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;

  await listCallQueue(db, "org-1", "school-1", 50);
  assertEquals(calls.length, 1);
  const { sql, args } = calls[0];
  // Same candidate source as the defaulters list (no duplicate source).
  assert(sql.includes("FROM finance_student_accounts fsa"));
  assert(sql.includes("fsa.status = 'open'"));
  assert(sql.includes("fsa.outstanding_amount > 0"));
  // Enriched with the telecaller signals.
  assert(sql.includes("finance_recovery_contacts"));
  assert(sql.includes("finance_promises_to_pay"));
  assert(sql.includes("has_broken_promise"));
  assert(sql.includes("pending_promise_date"));
  assert(sql.includes("LIMIT $3"));
  assertEquals(args, ["org-1", "school-1", 50]);
});
