// C2 · FIN-6 — installment/term due dates drive aging + the last hardcoded
// +30 due date is removed from the issue transition.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { overdueDaysSql, pickEffectiveDueDate } from "./finance_aging.ts";
import { listCallQueue } from "./finance_recovery_repository.ts";
import { issueInvoice } from "./finance_invoices_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

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

Deno.test("FIN-6: overdueDaysSql ages off the earliest NOT-YET-COVERED installment due date, falling back to invoice.due_date", () => {
  const sql = overdueDaysSql("fsa.student_id", "fsa.organization_id");
  // Uses the installment schedule…
  assert(sql.includes("finance_invoice_installments"));
  // …cumulative-summing term amounts in due-date order…
  assert(sql.includes("SUM(ii.amount_minor) OVER"));
  assert(sql.includes("ORDER BY ii.due_date, ii.term_no"));
  // …and picks the first term whose running total exceeds what's actually
  // been paid on the invoice so far (NOT the raw MIN(due_date) — that was the
  // FIN-PROD-2 bug: an early-paid term kept pinning aging to term 1 forever).
  assert(sql.includes("running_total >"));
  assert(
    sql.includes(
      "(fi.total_amount - fi.outstanding_amount + fi.late_fee_amount)",
    ),
  );
  assert(!sql.includes("MIN(ii.due_date)"));
  // …with a COALESCE fallback to the invoice's own due date (single-term /
  // legacy invoices age exactly as before).
  assert(sql.includes("fi.due_date"));
  assert(sql.includes("effective_due < CURRENT_DATE"));
  // Threads the caller's student/org columns.
  assert(sql.includes("fi.student_id = fsa.student_id"));
  assert(sql.includes("fi.organization_id = fsa.organization_id"));
  // The old single-column aging is gone.
  assert(!sql.includes("now() - fi.due_date"));
});

Deno.test("FIN-6: the call-queue query ages via the installment schedule", async () => {
  const { db, calls } = fakeDb();
  await listCallQueue(db, "org-1", "school-1", 50);
  const q = calls[0];
  assert(q.sql.includes("finance_invoice_installments"));
  assert(q.sql.includes("AS days_overdue"));
});

Deno.test("FIN-6: issueInvoice drops the hardcoded +30 and generates the schedule", async () => {
  const draft = {
    id: "inv-1",
    organization_id: "org-1",
    school_id: "school-1",
    invoice_status: "draft",
    total_amount: "50000",
  };
  const { db, calls } = fakeDb([
    { match: /SELECT \* FROM finance_invoices/, rows: [draft] },
    {
      match: /UPDATE finance_invoices/,
      rows: [{ ...draft, invoice_status: "issued" }],
    },
  ]);

  await issueInvoice(db, "org-1", "school-1", "inv-1");

  const update = calls.find((c) => /UPDATE finance_invoices/.test(c.sql))!;
  // No hardcoded +30 anymore — the due date is a bound parameter (config-driven).
  assert(!update.sql.includes("CURRENT_DATE + 30"));
  assert(update.sql.includes("due_date = $5"));
  // due_date param is a real ISO date (issue + due_days).
  const dueDate = update.args[4] as string;
  assert(/^\d{4}-\d{2}-\d{2}$/.test(dueDate), `expected ISO date, got ${dueDate}`);
  // The informational term-wise schedule is generated on issue too.
  assert(
    calls.some((c) => c.sql.includes("INSERT INTO finance_invoice_installments")),
    "issue must generate the installment schedule",
  );
});

Deno.test("FIN-6: aging is behaviour-preserving by default (COALESCE to invoice.due_date)", () => {
  // Documents the guarantee: when no schedule exists (legacy) or the single
  // default term's due date equals the invoice due date, effective_due falls
  // back to fi.due_date — so single-term / un-scheduled invoices age unchanged.
  const sql = overdueDaysSql("x.sid", "x.org").replace(/\s+/g, " ");
  assert(sql.includes("fi.due_date) AS effective_due"));
  assert(sql.includes("LIMIT 1 ), fi.due_date"));
});

// --- FIX 1 (P1-PROD gap sweep) --------------------------------------------
// `pickEffectiveDueDate` is the pure mirror of the SQL predicate above (see
// its docstring in finance_aging.ts) — it is what actually exercises the
// cumulative-sum "earliest still-unpaid term" algorithm in these unit tests,
// since there is no live Postgres in this repo's `deno test` run to execute
// the window-function SQL against.

Deno.test("FIX 1: single-term (default) invoice ages unchanged — always term 1 / invoice due_date, paid or not", () => {
  const dueDate = "2026-08-01";
  const installments = [{ dueDate, amount: 50000, termNo: 1 }];
  // Unpaid.
  assertEquals(pickEffectiveDueDate(installments, 0, dueDate), dueDate);
  // Partially paid — still the same single term/date (byte-identical to the
  // pre-fix behaviour, which always used the single MIN(due_date)).
  assertEquals(pickEffectiveDueDate(installments, 20000, dueDate), dueDate);
});

Deno.test("FIX 1: legacy invoice with no schedule falls back to invoice.due_date", () => {
  assertEquals(pickEffectiveDueDate([], 0, "2026-08-01"), "2026-08-01");
});

Deno.test("FIX 1: 2-term invoice, pay covering term 1 → aging reflects term 2 only (not term 1)", () => {
  const installments = [
    { dueDate: "2026-06-01", amount: 25000, termNo: 1 },
    { dueDate: "2026-12-01", amount: 25000, termNo: 2 },
  ];
  // Term 1 fully covered by what's been paid so far → the earliest
  // NOT-yet-covered term is term 2, not the old MIN(due_date) = term 1.
  assertEquals(
    pickEffectiveDueDate(installments, 25000, "2026-12-01"),
    "2026-12-01",
  );
  // Nothing paid yet → still pinned to term 1 (the genuinely-earliest unpaid
  // term).
  assertEquals(
    pickEffectiveDueDate(installments, 0, "2026-12-01"),
    "2026-06-01",
  );
  // Everything covered (e.g. paid in full, only an unrelated late fee keeps
  // the invoice non-"paid") → falls back to the invoice's own due_date.
  assertEquals(
    pickEffectiveDueDate(installments, 50000, "2026-12-01"),
    "2026-12-01",
  );
});
