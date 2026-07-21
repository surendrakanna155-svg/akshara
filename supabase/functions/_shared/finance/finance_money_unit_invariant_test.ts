// Money-unit invariant guards (ICA-A1 / ICA-A6).
//
// PERMANENT static invariants over the migration DDL (no DB, no network) — the
// same style as trunk_integrity_test.ts. They enforce the project money standard:
//
//   * every column whose name ends in `_minor` is BIGINT integer paise, and
//   * no live money column (payment_requests.amount, payment_intents.amount,
//     finance_collections.amount_collected) is INTEGER (which truncates paise).
//
// Migrations are append-only, so a column may be CREATEd then RENAMEd / retyped
// by a later migration. This resolves each (table.column) to its LATEST state
// across all migrations in version order, so historical DDL never false-fails.
//
// Run: deno test --allow-read supabase/functions/_shared/finance/finance_money_unit_invariant_test.ts

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

// This file lives in supabase/functions/_shared/finance/, so migrations are three
// directory levels up (finance → _shared → functions → supabase/migrations).
const MIGRATIONS = new URL("../../../migrations/", import.meta.url);

// ── Type normalization ───────────────────────────────────────────────────────
function normalizeBase(word: string): string {
  const w = word.trim().toLowerCase();
  const map: Record<string, string> = {
    int8: "BIGINT",
    bigint: "BIGINT",
    bigserial: "BIGINT",
    int4: "INTEGER",
    int: "INTEGER",
    integer: "INTEGER",
    serial: "INTEGER",
    int2: "SMALLINT",
    smallint: "SMALLINT",
    numeric: "NUMERIC",
    decimal: "NUMERIC",
  };
  return map[w] ?? w.toUpperCase();
}

function normalizeTable(name: string): string {
  let t = name.trim().toLowerCase();
  if (t.startsWith("public.")) t = t.slice(7);
  return t;
}

// Strip `--` line comments so comment text (which can contain unbalanced parens,
// e.g. `-- "category:label" (or 'general:General')`) never corrupts paren
// counting or false-matches a DDL pattern.
function stripComments(sql: string): string {
  return sql.split("\n").map((line) => line.replace(/--.*$/, "")).join("\n");
}

function extractBalanced(sql: string, openIdx: number): string {
  let depth = 0;
  for (let i = openIdx; i < sql.length; i++) {
    const ch = sql[i];
    if (ch === "(") depth++;
    else if (ch === ")") {
      depth--;
      if (depth === 0) return sql.slice(openIdx + 1, i);
    }
  }
  return "";
}

function splitTopLevel(body: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < body.length; i++) {
    const ch = body[i];
    if (ch === "(") depth++;
    else if (ch === ")") depth--;
    else if (ch === "," && depth === 0) {
      parts.push(body.slice(start, i));
      start = i + 1;
    }
  }
  parts.push(body.slice(start));
  return parts.map((p) => p.trim()).filter((p) => p.length > 0);
}

const CONSTRAINT_KW = new Set([
  "constraint",
  "primary",
  "foreign",
  "unique",
  "check",
  "exclude",
  "like",
  "partition",
]);

function parseColumnDef(def: string): { name: string; type: string } | null {
  const m = def.match(/^"?([a-z_][a-z0-9_]*)"?\s+([\s\S]+)$/i);
  if (!m) return null;
  const name = m[1].toLowerCase();
  if (CONSTRAINT_KW.has(name)) return null;
  const base = m[2].trim().match(/^([a-z_][a-z0-9_]*)/i);
  if (!base) return null;
  return { name, type: normalizeBase(base[1]) };
}

// ── Build the resolved (table.column → type) map ─────────────────────────────
function migrationFiles(): string[] {
  const names: string[] = [];
  for (const e of Deno.readDirSync(MIGRATIONS)) {
    if (e.isFile && e.name.endsWith(".sql")) names.push(e.name);
  }
  return names.sort();
}

function buildColumnTypeMap(): Map<string, string> {
  const map = new Map<string, string>();
  const createRe =
    /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?((?:[a-z_][a-z0-9_]*\.)?[a-z_][a-z0-9_]*)\s*\(/gi;
  const addColRe =
    /ALTER\s+TABLE\s+(?:ONLY\s+)?(?:IF\s+EXISTS\s+)?((?:[a-z_][a-z0-9_]*\.)?[a-z_][a-z0-9_]*)\s+ADD\s+COLUMN\s+(?:IF\s+NOT\s+EXISTS\s+)?"?([a-z_][a-z0-9_]*)"?\s+([a-z_][a-z0-9_]*)/gi;
  const renameRe =
    /ALTER\s+TABLE\s+(?:ONLY\s+)?(?:IF\s+EXISTS\s+)?((?:[a-z_][a-z0-9_]*\.)?[a-z_][a-z0-9_]*)\s+RENAME\s+COLUMN\s+(?:IF\s+EXISTS\s+)?"?([a-z_][a-z0-9_]*)"?\s+TO\s+"?([a-z_][a-z0-9_]*)"?/gi;
  const alterTypeRe =
    /ALTER\s+TABLE\s+(?:ONLY\s+)?(?:IF\s+EXISTS\s+)?((?:[a-z_][a-z0-9_]*\.)?[a-z_][a-z0-9_]*)\s+ALTER\s+COLUMN\s+"?([a-z_][a-z0-9_]*)"?\s+(?:SET\s+DATA\s+)?TYPE\s+([a-z_][a-z0-9_]*)/gi;

  // Files in version order so a later RENAME / ALTER TYPE wins over the CREATE.
  for (const f of migrationFiles()) {
    const sql = stripComments(Deno.readTextFileSync(new URL(f, MIGRATIONS)));

    for (const m of sql.matchAll(createRe)) {
      const table = normalizeTable(m[1]);
      const openIdx = m.index! + m[0].length - 1; // last char of match is '('
      const body = extractBalanced(sql, openIdx);
      for (const def of splitTopLevel(body)) {
        const col = parseColumnDef(def);
        if (col) map.set(`${table}.${col.name}`, col.type);
      }
    }
    for (const m of sql.matchAll(addColRe)) {
      map.set(`${normalizeTable(m[1])}.${m[2].toLowerCase()}`, normalizeBase(m[3]));
    }
    for (const m of sql.matchAll(renameRe)) {
      const table = normalizeTable(m[1]);
      const oldKey = `${table}.${m[2].toLowerCase()}`;
      const newKey = `${table}.${m[3].toLowerCase()}`;
      const t = map.get(oldKey);
      if (t !== undefined) {
        map.set(newKey, t);
        map.delete(oldKey);
      }
    }
    for (const m of sql.matchAll(alterTypeRe)) {
      map.set(`${normalizeTable(m[1])}.${m[2].toLowerCase()}`, normalizeBase(m[3]));
    }
  }
  return map;
}

// Known misnamed NUMERIC(12,2)-rupee columns (migration 20260827000000). They are
// money-SAFE (NUMERIC never truncates) but carry a `_minor` suffix the spec kept.
// The `_minor` → plain rename is a tracked, cross-module change (transport_expenses,
// finance_mapper, finance_aging all read these columns) deferred out of the ICA-A1
// PR. The invariant still forbids them ever regressing to INTEGER, and asserts they
// stay NUMERIC until the coordinated rename lands.
const DEFERRED_NUMERIC_MINOR = new Set([
  "finance_invoice_installments.amount_minor",
  "finance_invoice_head_allocations.head_total_minor",
  "finance_invoice_head_allocations.head_paid_minor",
]);

Deno.test("money-invariant: parser resolves a healthy set of columns (anti-vacuous floor)", () => {
  const map = buildColumnTypeMap();
  assert(map.size > 100, `expected many resolved columns, found ${map.size}`);
  // Anchor known BIGINT paise columns so a silently-broken parse can't pass.
  assertEquals(map.get("finance_promises_to_pay.amount_minor"), "BIGINT");
  assertEquals(map.get("finance_recovery_targets.target_minor"), "BIGINT");
  assertEquals(map.get("finance_fee_concessions.amount_minor"), "BIGINT");
});

Deno.test("money-invariant: every `_minor` column is BIGINT integer paise (never INTEGER)", () => {
  const map = buildColumnTypeMap();
  const minorCols = [...map.entries()].filter(([k]) => k.split(".")[1].endsWith("_minor"));
  assert(minorCols.length >= 3, `expected >=3 _minor columns, found ${minorCols.length}`);

  for (const [key, type] of minorCols) {
    // A paise column must NEVER be INTEGER — INTEGER is fine numerically but the
    // guard exists so no one re-types a minor column back to a truncating scalar.
    assert(type !== "INTEGER", `${key} is INTEGER — a paise column must never truncate`);
    if (DEFERRED_NUMERIC_MINOR.has(key)) {
      assertEquals(type, "NUMERIC", `${key} must stay NUMERIC until the tracked rename lands`);
      continue;
    }
    assertEquals(type, "BIGINT", `${key} must be BIGINT integer paise`);
  }
});

Deno.test("money-invariant: payment + collection money columns are NUMERIC rupees, never INTEGER (ICA-A6)", () => {
  const map = buildColumnTypeMap();
  for (const key of [
    "payment_requests.amount",
    "payment_intents.amount",
    "finance_collections.amount_collected",
  ]) {
    const t = map.get(key);
    assert(t !== undefined, `expected to find money column ${key} in the migration DDL`);
    assert(
      t !== "INTEGER",
      `${key} is INTEGER — money must be NUMERIC(12,2) rupees (or BIGINT paise), never a truncating INTEGER`,
    );
    // Stronger: these three are the finance-standard NUMERIC(12,2) rupee scale.
    // This fails if migration 20260920000062 (payment amount → NUMERIC) is reverted.
    assertEquals(t, "NUMERIC", `${key} must be NUMERIC(12,2) rupees`);
  }
});
