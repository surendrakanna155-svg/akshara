// Migration re-runnability guard (ICA-E3 — "Inconsistent migration idempotency guards").
//
// PROBLEM (ICA-E3, P2, Database): the migration set mixes idempotency conventions
// — some objects use `IF NOT EXISTS` while others don't, and a single migration
// can mix `ADD COLUMN IF NOT EXISTS` with an unguarded `ADD CONSTRAINT`. A
// migration that fails halfway then can't always be safely re-applied.
//
// WHY THIS IS A FORWARD-LOOKING STATIC GUARD (not a rewrite): the 244 historical
// migrations have already been applied to the live pilot; editing them changes
// their checksums and risks ledger divergence. Rewriting applied history to add
// guards is unsafe and pointless. The correct, safe fix is to enforce the
// re-runnability convention on NEW migrations going forward and GRANDFATHER
// everything before the cutoff. This is a pure static check over
// `supabase/migrations/*.sql` (no DB, no network), in the same house style as
// `trunk_integrity_test.ts`. Run with:
//
//   deno test --allow-read supabase/functions/_shared/migration_rerunnability_guard_test.ts
//
// GRANDFATHER CUTOFF (inclusive): every migration whose 14-digit version is
// >= CUTOFF must be re-runnable; everything strictly below is exempt (already
// applied history). The cutoff is set at the ICA hardening batch
// (20260920000060…), so the batch that introduced this convention — and every
// migration authored after it — is enforced, while the 244 historical ones are
// left untouched.
//
// RE-RUNNABILITY RULES ENFORCED (per in-scope migration, over comment-stripped SQL):
//   R1  CREATE TABLE                     -> must be `CREATE TABLE IF NOT EXISTS`.
//   R2  CREATE [UNIQUE] INDEX [CONCURRENTLY] -> must carry `IF NOT EXISTS`.
//   R3  ADD COLUMN                       -> must be `ADD COLUMN IF NOT EXISTS`.
//   R4  CREATE POLICY <name>             -> must be preceded by
//                                           `DROP POLICY IF EXISTS <name>`.
//   R5  CREATE FUNCTION / PROCEDURE      -> must be `CREATE OR REPLACE`.
//   R6  CREATE TRIGGER <name>            -> must be `CREATE OR REPLACE TRIGGER`
//                                           or preceded by `DROP TRIGGER IF EXISTS <name>`.
//   R7  ALTER TABLE … ADD CONSTRAINT     -> must be guarded: either inside a
//                                           `DO $$ … $$` block that performs a
//                                           `pg_constraint` existence check, or
//                                           preceded (top-level) by
//                                           `DROP CONSTRAINT IF EXISTS`. A bare
//                                           top-level `ADD CONSTRAINT` fails.
//                                           (Prefer a UNIQUE INDEX IF NOT EXISTS
//                                           where a UNIQUE constraint is intended —
//                                           20260920000170 does exactly this.)
//
// DELIBERATE ONE-SHOT EXEMPTION: a data migration that is intentionally NOT
// idempotent (e.g. a one-time money-scale correction that multiplies rows) may
// declare itself with an explicit, auditable marker in a leading comment —
// `NOT IDEMPOTENT BY DESIGN` or `@rerunnable: exempt`. Such a file is recorded as
// a documented one-shot and excluded from the assertions (but still reported).
// 20260920000060 (recovery money backfill, UPDATE ×100) is the sole current
// exemption and carries the marker.
//
// FALSE-POSITIVE AVOIDANCE:
//   * `--` and `/* … */` comments are stripped first, so the descriptive header
//     comments (which name DDL keywords) never trigger a rule.
//   * Dollar-quoted blocks (`DO $do$ … $do$`, function bodies `AS $$ … $$`) are
//     separated from top-level SQL: R1–R6 run on top-level SQL only (so DML inside
//     a function body is never mistaken for migration DDL), and the ADD CONSTRAINT
//     guard (R7) treats an in-DO-block constraint as guarded iff the block does a
//     `pg_constraint` check — matching the house pattern in 20260920000160.
//   * `ADD CONSTRAINT` is an ALTER-only token (a table-def constraint uses
//     `CONSTRAINT`, never `ADD CONSTRAINT`), so a constraint declared inside a
//     CREATE TABLE is never flagged.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const HERE = new URL(".", import.meta.url); // supabase/functions/_shared/
const MIGRATIONS = new URL("../../migrations/", HERE); // supabase/migrations/

// Inclusive grandfather cutoff — enforce >= this version, exempt everything below.
const CUTOFF = "20260920000060";

// Anti-vacuous floors (see the dedicated non-vacuity test below for the strongest
// proof — synthetic bad SQL that the checker MUST flag).
const MIN_IN_SCOPE = 10; // grandfather floor: the guard must actually cover a real set.
const MIN_WITH_DDL = 8; // of those, this many must carry an enforced DDL statement.

function listMigrations(): string[] {
  const names: string[] = [];
  for (const e of Deno.readDirSync(MIGRATIONS)) {
    if (e.isFile && e.name.endsWith(".sql")) names.push(e.name);
  }
  return names.sort();
}

/** Strip `/* … *​/` block comments and `-- …` line comments. Keyword-scan only —
 * corrupting a string literal's tail is harmless since this SQL is never executed. */
function stripComments(sql: string): string {
  return sql.replace(/\/\*[\s\S]*?\*\//g, " ").replace(/--[^\n]*/g, " ");
}

/** Split dollar-quoted blocks (`$tag$ … $tag$`, incl. empty tag `$$ … $$`) from the
 * surrounding top-level SQL. Returns the block texts and the top-level remainder
 * (each block replaced by a newline placeholder to preserve statement ordering). */
function splitDollarBlocks(sql: string): { blocks: string[]; topLevel: string } {
  const re = /\$([A-Za-z_][A-Za-z0-9_]*|)\$[\s\S]*?\$\1\$/g;
  const blocks: string[] = [];
  const topLevel = sql.replace(re, (m) => {
    blocks.push(m);
    return "\n";
  });
  return { blocks, topLevel };
}

function isExempt(rawSql: string): boolean {
  return /NOT\s+IDEMPOTENT\s+BY\s+DESIGN/i.test(rawSql) ||
    /@rerunnable:\s*exempt/i.test(rawSql);
}

// DDL statement kinds this guard enforces — used for the "exercised" floor.
const ENFORCED_DDL_RE =
  /\bCREATE\s+(?:GLOBAL\s+|LOCAL\s+)?(?:TEMP(?:ORARY)?\s+|UNLOGGED\s+)?TABLE\b|\bCREATE\s+(?:UNIQUE\s+)?INDEX\b|\bADD\s+COLUMN\b|\bCREATE\s+POLICY\b|\bCREATE\s+(?:OR\s+REPLACE\s+)?(?:FUNCTION|PROCEDURE)\b|\bCREATE\s+(?:OR\s+REPLACE\s+)?(?:CONSTRAINT\s+)?TRIGGER\b|\bADD\s+CONSTRAINT\b/i;

function hasEnforcedDDL(rawSql: string): boolean {
  const clean = stripComments(rawSql);
  return ENFORCED_DDL_RE.test(clean);
}

/**
 * Return every re-runnability violation found in a migration's SQL text.
 * Empty array => the migration is safely re-runnable under the rules above.
 */
export function findRerunnabilityViolations(rawSql: string): string[] {
  const clean = stripComments(rawSql);
  const { blocks, topLevel } = splitDollarBlocks(clean);
  const v: string[] = [];

  // R1 — CREATE TABLE must be IF NOT EXISTS.
  for (
    const m of topLevel.matchAll(
      /\bCREATE\s+(?:GLOBAL\s+|LOCAL\s+)?(?:TEMP(?:ORARY)?\s+|UNLOGGED\s+)?TABLE\s+(?!IF\s+NOT\s+EXISTS\b)([^\s(;]+)/gi,
    )
  ) {
    v.push(`R1 CREATE TABLE ${m[1]} without IF NOT EXISTS`);
  }

  // R2 — CREATE [UNIQUE] INDEX [CONCURRENTLY] must be IF NOT EXISTS.
  for (
    const m of topLevel.matchAll(
      /\bCREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:CONCURRENTLY\s+)?(?!IF\s+NOT\s+EXISTS\b)([^\s(;]+)/gi,
    )
  ) {
    v.push(`R2 CREATE INDEX ${m[1]} without IF NOT EXISTS`);
  }

  // R3 — ADD COLUMN must be IF NOT EXISTS.
  for (
    const m of topLevel.matchAll(
      /\bADD\s+COLUMN\s+(?!IF\s+NOT\s+EXISTS\b)([^\s(;]+)/gi,
    )
  ) {
    v.push(`R3 ADD COLUMN ${m[1]} without IF NOT EXISTS`);
  }

  // R4 — every CREATE POLICY must be preceded by DROP POLICY IF EXISTS <same name>.
  const policyDrops: { name: string; idx: number }[] = [];
  for (
    const m of topLevel.matchAll(/\bDROP\s+POLICY\s+IF\s+EXISTS\s+"?([A-Za-z0-9_]+)"?/gi)
  ) {
    policyDrops.push({ name: m[1].toLowerCase(), idx: m.index ?? 0 });
  }
  for (const m of topLevel.matchAll(/\bCREATE\s+POLICY\s+"?([A-Za-z0-9_]+)"?/gi)) {
    const name = m[1].toLowerCase();
    const idx = m.index ?? 0;
    if (!policyDrops.some((d) => d.name === name && d.idx < idx)) {
      v.push(`R4 CREATE POLICY ${name} not preceded by DROP POLICY IF EXISTS ${name}`);
    }
  }

  // R5 — CREATE FUNCTION / PROCEDURE must be CREATE OR REPLACE.
  for (
    const m of topLevel.matchAll(
      /\bCREATE\s+(OR\s+REPLACE\s+)?(FUNCTION|PROCEDURE)\s+([^\s(;]+)/gi,
    )
  ) {
    if (!m[1]) v.push(`R5 CREATE ${m[2].toUpperCase()} ${m[3]} without OR REPLACE`);
  }

  // R6 — CREATE TRIGGER must be OR REPLACE, or preceded by DROP TRIGGER IF EXISTS.
  const trigDrops: { name: string; idx: number }[] = [];
  for (
    const m of topLevel.matchAll(/\bDROP\s+TRIGGER\s+IF\s+EXISTS\s+"?([A-Za-z0-9_]+)"?/gi)
  ) {
    trigDrops.push({ name: m[1].toLowerCase(), idx: m.index ?? 0 });
  }
  for (
    const m of topLevel.matchAll(
      /\bCREATE\s+(OR\s+REPLACE\s+)?(?:CONSTRAINT\s+)?TRIGGER\s+"?([A-Za-z0-9_]+)"?/gi,
    )
  ) {
    if (m[1]) continue; // CREATE OR REPLACE TRIGGER (PG14+) is idempotent.
    const name = m[2].toLowerCase();
    const idx = m.index ?? 0;
    if (!trigDrops.some((d) => d.name === name && d.idx < idx)) {
      v.push(
        `R6 CREATE TRIGGER ${name} not OR REPLACE and not preceded by DROP TRIGGER IF EXISTS ${name}`,
      );
    }
  }

  // R7a — a top-level ADD CONSTRAINT (not inside a DO block) must be preceded by
  // DROP CONSTRAINT IF EXISTS (drop-then-add). A bare one is un-re-runnable.
  for (const m of topLevel.matchAll(/\bADD\s+CONSTRAINT\b/gi)) {
    const before = topLevel.slice(0, m.index ?? 0);
    if (!/\bDROP\s+CONSTRAINT\s+IF\s+EXISTS\b/i.test(before)) {
      v.push(
        "R7 top-level ADD CONSTRAINT not preceded by DROP CONSTRAINT IF EXISTS " +
          "(wrap it in a DO/pg_constraint existence guard, drop-then-add, or use a UNIQUE INDEX IF NOT EXISTS)",
      );
    }
  }
  // R7b — an ADD CONSTRAINT inside a DO/dollar block must be guarded by a
  // pg_constraint existence check (the house 20260920000160 pattern).
  for (const b of blocks) {
    if (/\bADD\s+CONSTRAINT\b/i.test(b) && !/\bpg_constraint\b/i.test(b)) {
      v.push(
        "R7 ADD CONSTRAINT inside a DO/dollar block without a pg_constraint existence guard",
      );
    }
  }

  return v;
}

Deno.test("migration re-runnability: every in-scope migration (>= cutoff) is safely re-runnable", () => {
  const files = listMigrations();
  assert(files.length > 100, `expected the full migration set, found ${files.length}`);

  const inScope = files.filter((f) => f.slice(0, 14) >= CUTOFF);
  assert(
    inScope.length >= MIN_IN_SCOPE,
    `anti-vacuous floor: expected >= ${MIN_IN_SCOPE} in-scope migrations (>= ${CUTOFF}), found ${inScope.length}`,
  );

  const offenders: string[] = [];
  const exempt: string[] = [];
  let withDDL = 0;

  for (const f of inScope) {
    const raw = Deno.readTextFileSync(new URL(f, MIGRATIONS));
    if (hasEnforcedDDL(raw)) withDDL++;
    if (isExempt(raw)) {
      exempt.push(f);
      continue; // documented one-shot (e.g. a ×100 money backfill) — not asserted.
    }
    const violations = findRerunnabilityViolations(raw);
    if (violations.length > 0) {
      offenders.push(`${f}:\n    - ${violations.join("\n    - ")}`);
    }
  }

  // Non-vacuity: the guard must actually have EXERCISED its rules on real DDL.
  assert(
    withDDL >= MIN_WITH_DDL,
    `anti-vacuous floor: expected >= ${MIN_WITH_DDL} in-scope migrations carrying enforced DDL, found ${withDDL}`,
  );

  assertEquals(
    offenders,
    [],
    "Non-re-runnable migration(s) found (>= cutoff " + CUTOFF + "). " +
      "Each new migration must be safely re-applyable — see the rules at the top of this file. " +
      "Documented one-shots must carry a `NOT IDEMPOTENT BY DESIGN` / `@rerunnable: exempt` marker. " +
      "Exempt (skipped): [" + exempt.join(", ") + "].\n" + offenders.join("\n"),
  );
});

Deno.test("migration re-runnability: guard is non-vacuous (it flags un-re-runnable SQL)", () => {
  // Negative controls — each MUST produce at least one violation, proving the
  // checker discriminates (a guard that never fails is worthless).
  const bad: [string, string][] = [
    ["R1", "CREATE TABLE foo (id uuid primary key);"],
    ["R2", "CREATE INDEX idx_foo ON foo (id);"],
    ["R2", "CREATE UNIQUE INDEX uq_foo ON foo (id);"],
    ["R3", "ALTER TABLE foo ADD COLUMN bar text;"],
    ["R4", "CREATE POLICY foo_read ON foo FOR SELECT USING (true);"],
    ["R5", "CREATE FUNCTION f() RETURNS void LANGUAGE sql AS $$ SELECT 1 $$;"],
    ["R6", "CREATE TRIGGER t BEFORE INSERT ON foo FOR EACH ROW EXECUTE FUNCTION f();"],
    ["R7", "ALTER TABLE foo ADD CONSTRAINT foo_uq UNIQUE (id);"],
    [
      "R7",
      "DO $do$ BEGIN ALTER TABLE foo ADD CONSTRAINT foo_fk FOREIGN KEY (id) REFERENCES bar(id); END $do$;",
    ],
  ];
  for (const [label, sql] of bad) {
    const found = findRerunnabilityViolations(sql);
    assert(found.length > 0, `${label}: expected a violation for un-re-runnable SQL: ${sql}`);
  }

  // Positive controls — the house-idiomatic guarded forms must produce ZERO
  // violations (no false positives).
  const good: string[] = [
    "CREATE TABLE IF NOT EXISTS foo (id uuid primary key);",
    "CREATE INDEX IF NOT EXISTS idx_foo ON foo (id);",
    "CREATE UNIQUE INDEX IF NOT EXISTS uq_foo ON foo (id) WHERE id IS NOT NULL;",
    "ALTER TABLE foo ADD COLUMN IF NOT EXISTS bar text;",
    "ALTER TABLE foo ALTER COLUMN amount TYPE numeric(12,2) USING amount::numeric(12,2);",
    "DROP POLICY IF EXISTS foo_read ON foo; CREATE POLICY foo_read ON foo FOR SELECT USING (true);",
    "CREATE OR REPLACE FUNCTION f() RETURNS void LANGUAGE sql AS $$ SELECT 1 $$;",
    "DROP TRIGGER IF EXISTS t ON foo; CREATE TRIGGER t BEFORE INSERT ON foo FOR EACH ROW EXECUTE FUNCTION f();",
    "CREATE OR REPLACE TRIGGER t BEFORE INSERT ON foo FOR EACH ROW EXECUTE FUNCTION f();",
    "ALTER TABLE foo DROP CONSTRAINT IF EXISTS foo_uq; ALTER TABLE foo ADD CONSTRAINT foo_uq UNIQUE (id);",
    "DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'foo_fk') THEN " +
    "ALTER TABLE foo ADD CONSTRAINT foo_fk FOREIGN KEY (id) REFERENCES bar(id) NOT VALID; END IF; END $do$;",
    // A pure-data UPDATE migration (no DDL) is trivially clean under these rules.
    "UPDATE finance_promises_to_pay SET amount_minor = amount_minor * 100;",
    // Comments naming DDL keywords must NOT trigger (comment-stripping).
    "-- CREATE TABLE foo without IF NOT EXISTS would be bad\nUPDATE x SET y = 1;",
  ];
  for (const sql of good) {
    const found = findRerunnabilityViolations(sql);
    assertEquals(found, [], `false positive on house-idiomatic SQL: ${sql}\n  -> ${found.join("; ")}`);
  }
});
