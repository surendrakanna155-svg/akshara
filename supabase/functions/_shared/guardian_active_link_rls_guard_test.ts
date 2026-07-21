// Guardian ACTIVE-link RLS drift guard (ICA-B1 — P0 Security).
//
// PERMANENT invariant. The guardian-unlink writer is a SOFT unlink: it sets
// `student_guardians.status = 'inactive'` and keeps the row, so RLS is the real
// de-authorization boundary. EVERY parent-scope policy that gates a child's
// records through a `student_guardians` sub-select
//
//     student_id IN (SELECT ... FROM student_guardians
//                    WHERE guardian_user_id = app_current_parent_user_id() ...)
//
// MUST also require `status = 'active'` (accept `sg.status = 'active'`) inside
// that sub-select — otherwise a de-authorized (inactive) guardian keeps reading
// or acting on a revoked child's records. The homework migration
// (20260836000000) once reintroduced exactly this drift; this static guard
// fails CI if any future migration recreates a parent-scope guardian policy
// without the predicate.
//
// Pure static check over supabase/migrations/*.sql (no DB, no network). Run:
//   deno test --allow-read supabase/functions/_shared/guardian_active_link_rls_guard_test.ts

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const HERE = new URL(".", import.meta.url); // supabase/functions/_shared/
const MIGRATIONS = new URL("../../migrations/", HERE); // supabase/migrations/

const ICA_B1_MIGRATION = "20260920000080_ica_b1_guardian_active_link_rls_comprehensive.sql";

// The seven policies ICA-B1 tightened. Each must resolve to the ICA-B1 migration.
const FIXED_POLICIES = [
  "attendance_records_parent_student_read",
  "exam_mark_entries_school",
  "exam_remarks_access",
  "homework_submissions_parent_read",
  "intel_parent_guidance_parent_scope",
  "attendance_corrections_parent_read",
  "attendance_corrections_parent_insert",
];

function migrationFilesSorted(): string[] {
  const names: string[] = [];
  for (const e of Deno.readDirSync(MIGRATIONS)) {
    if (e.isFile && e.name.endsWith(".sql")) names.push(e.name);
  }
  return names.sort(); // 14-digit numeric prefix => chronological
}

// Extract a full CREATE POLICY statement starting at `start`, terminating at the
// first `;` at paren-depth 0. String literals are skipped so a `';'` inside a
// quoted value never ends the statement early.
function extractStatement(sql: string, start: number): string {
  let depth = 0;
  for (let i = start; i < sql.length; i++) {
    const c = sql[i];
    if (c === "'") {
      i++;
      while (i < sql.length && sql[i] !== "'") i++;
    } else if (c === "(") {
      depth++;
    } else if (c === ")") {
      depth--;
    } else if (c === ";" && depth === 0) {
      return sql.slice(start, i + 1);
    }
  }
  return sql.slice(start);
}

type Effective = { file: string; table: string; body: string };

// Build the EFFECTIVE (last-writer-wins) policy set by replaying CREATE and bare
// DROP events in chronological order. A DROP that is not followed by a recreate
// removes the policy (e.g. homework_submissions_scope, dropped at 20260836000000).
function buildEffectivePolicies(): Map<string, Effective> {
  const state = new Map<string, Effective | null>(); // null === dropped
  const eventRe =
    /CREATE\s+POLICY\s+(\w+)\s+ON\s+([\w.]+)|DROP\s+POLICY\s+(?:IF\s+EXISTS\s+)?(\w+)\s+ON\s+[\w.]+/gi;
  for (const file of migrationFilesSorted()) {
    const sql = Deno.readTextFileSync(new URL(file, MIGRATIONS));
    for (const m of sql.matchAll(eventRe)) {
      if (m[1]) {
        // CREATE
        const body = extractStatement(sql, m.index!);
        state.set(m[1], { file, table: m[2], body });
      } else if (m[3]) {
        // bare DROP
        state.set(m[3], null);
      }
    }
  }
  const effective = new Map<string, Effective>();
  for (const [name, v] of state) if (v) effective.set(name, v);
  return effective;
}

// For a policy body, return each `FROM student_guardians` sub-select block whose
// WHERE targets the calling parent (guardian_user_id = app_current_parent_user_id()).
// A sub-select block is the fully paren-matched span opening at the `(` that
// introduces the sub-SELECT. This deliberately EXCLUDES the self-policy on
// student_guardians (student_guardians_scope_access), whose parent predicate is a
// direct row match, not a `SELECT ... FROM student_guardians` sub-select.
function parentGuardianSubselects(body: string): string[] {
  const blocks: string[] = [];
  const fromRe = /FROM\s+student_guardians\b/gi;
  for (const fm of body.matchAll(fromRe)) {
    const at = fm.index!;
    const selectPos = body.lastIndexOf("SELECT", at);
    if (selectPos < 0) continue;
    const openParen = body.lastIndexOf("(", selectPos);
    if (openParen < 0) continue;
    // paren-match forward from openParen
    let depth = 0;
    let block = "";
    for (let i = openParen; i < body.length; i++) {
      const c = body[i];
      if (c === "'") {
        i++;
        while (i < body.length && body[i] !== "'") i++;
      } else if (c === "(") {
        depth++;
      } else if (c === ")") {
        depth--;
        if (depth === 0) {
          block = body.slice(openParen, i + 1);
          break;
        }
      }
    }
    if (/guardian_user_id\s*=\s*app_current_parent_user_id\(\)/.test(block)) {
      blocks.push(block);
    }
  }
  return blocks;
}

const HAS_ACTIVE = /status\s*=\s*'active'/; // matches `status = 'active'` and `sg.status = 'active'`

Deno.test("ica-b1: every parent-scope guardian sub-select requires status='active'", () => {
  const effective = buildEffectivePolicies();
  const offenders: string[] = [];
  let totalBlocks = 0;
  for (const [name, { file, body }] of effective) {
    for (const block of parentGuardianSubselects(body)) {
      totalBlocks++;
      if (!HAS_ACTIVE.test(block)) {
        offenders.push(`${name} (${file})`);
      }
    }
  }
  // Sanity floor: a broken regex must not vacuously pass. The effective set has
  // well over a dozen parent-scope guardian sub-selects.
  assert(
    totalBlocks >= 15,
    `expected >=15 parent-scope guardian sub-selects, found ${totalBlocks} — detection likely broke`,
  );
  assertEquals(
    offenders,
    [],
    `parent-scope guardian sub-select(s) missing AND status='active' (RLS leak to de-authorized guardians): ${
      offenders.join(", ")
    }`,
  );
});

Deno.test("ica-b1: the seven fixed policies resolve to the ICA-B1 migration", () => {
  const effective = buildEffectivePolicies();
  for (const name of FIXED_POLICIES) {
    const eff = effective.get(name);
    assert(eff, `expected policy ${name} to exist in the effective set`);
    assertEquals(
      eff!.file,
      ICA_B1_MIGRATION,
      `policy ${name} should be last recreated by ${ICA_B1_MIGRATION}, but resolves to ${eff!.file} — ` +
        `a later migration recreated it (re-verify it kept AND status='active')`,
    );
    // And the ICA-B1 definition itself must carry the predicate.
    for (const block of parentGuardianSubselects(eff!.body)) {
      assert(
        HAS_ACTIVE.test(block),
        `ICA-B1 policy ${name} has a guardian sub-select without status='active'`,
      );
    }
  }
});

Deno.test("ica-b1: the self-policy on student_guardians is NOT treated as a sub-select", () => {
  // student_guardians_scope_access matches the parent via a DIRECT row predicate,
  // not a `SELECT ... FROM student_guardians` sub-select, so it is intentionally
  // out of scope for this guard. Guarantees the detector excludes it.
  const effective = buildEffectivePolicies();
  const self = effective.get("student_guardians_scope_access");
  assert(self, "expected student_guardians_scope_access to exist");
  assertEquals(
    parentGuardianSubselects(self!.body).length,
    0,
    "self-policy on student_guardians must not be detected as a guardian sub-select",
  );
});
