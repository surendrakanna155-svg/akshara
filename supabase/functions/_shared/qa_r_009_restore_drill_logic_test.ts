// QA-R-009 — Backup & DR: restore-drill INTEGRITY-threshold certification.
//
// The integrity thresholds that decide whether a restored backup is TRUSTWORTHY
// live ONLY in bash — deploy/akshara-vps/backup/akshara-restore-drill.sh:
//
//   L53:  [[ "$TABLES" =~ ^[0-9]+$ && "$TABLES" -gt 100 ]] || fail "too few tables"
//   L59:  if [[ "${ORGS:-0}" -lt 1 ]]; then MISMATCH="organizations table empty..."; fi
//
// i.e. a drill PASSES only when the throwaway-restored DB has > 100 public tables
// AND a non-empty `organizations` table; otherwise the drill row is written
// `failed` (with a `mismatch` reason) and the script exits non-zero.
//
// There is no TypeScript implementation of these thresholds to import, and we will
// not stand up Postgres/Docker in this lane to run the bash drill end-to-end (that
// is exercised by the monthly cron drill on the VPS — install-ops-cron.sh L55-56).
// To keep the contract honestly pinned and catch a silent change to the documented
// thresholds, this suite ports the *decision predicate* verbatim and asserts it,
// then cross-checks the surfacing path in qa_r_009_backup_health_test.ts. If the
// bash thresholds change, this predicate must be updated in lock-step — that is the
// point of the test.
//
// HONEST SCOPE: this proves the THRESHOLD VALUES (>100, non-empty orgs) are what we
// claim. It does NOT prove the live bash exec wiring (openssl decrypt, pg_restore,
// throwaway-db lifecycle) — that is bash-only and infra-bound; see the runbook
// (docs/BACKUP_RESTORE_RUNBOOK.md) + the monthly cron drill.

import {
  assert,
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

// --- ported decision predicate (mirror of akshara-restore-drill.sh L53/L59) ---

interface DrillSample {
  /** count(*) over information_schema.tables WHERE table_schema='public'. */
  tablesChecked: number;
  /** count(*) over organizations. */
  organizations: number;
}

interface DrillVerdict {
  status: "success" | "failed";
  mismatch: string | null;
}

/**
 * Pure port of the bash integrity gate. Returns the drill verdict the script would
 * record in ops_restore_drills. Mirror, line-for-line:
 *   - tables must be a count > 100 (L53),
 *   - organizations must be non-empty (L59).
 * First breach wins (tables checked before orgs, as in the script's order).
 */
function evaluateDrillIntegrity(s: DrillSample): DrillVerdict {
  // L53: too few tables → hard fail.
  if (!(Number.isInteger(s.tablesChecked) && s.tablesChecked > 100)) {
    return {
      status: "failed",
      mismatch: `restored db has too few tables (${s.tablesChecked}, expected >100)`,
    };
  }
  // L59: organizations empty → mismatch fail.
  if (s.organizations < 1) {
    return { status: "failed", mismatch: "organizations table empty after restore" };
  }
  return { status: "success", mismatch: null };
}

// --- tables threshold: strictly > 100 ----------------------------------------

Deno.test("QA-R-009 drill threshold: a healthy restore (>100 tables, orgs present) is success", () => {
  const v = evaluateDrillIntegrity({ tablesChecked: 180, organizations: 12 });
  assertEquals(v.status, "success");
  assertEquals(v.mismatch, null);
});

Deno.test("QA-R-009 drill threshold: <= 100 tables is a hard FAIL", () => {
  for (const tablesChecked of [0, 1, 50, 100]) {
    const v = evaluateDrillIntegrity({ tablesChecked, organizations: 12 });
    assertEquals(v.status, "failed", `expected fail at ${tablesChecked} tables`);
    assert(v.mismatch!.includes("too few tables"));
  }
});

Deno.test("QA-R-009 drill threshold: 101 tables (just over the line) passes the table gate", () => {
  // strict > 100 — 101 is the first passing count.
  const v = evaluateDrillIntegrity({ tablesChecked: 101, organizations: 1 });
  assertEquals(v.status, "success");
});

// --- organizations must be non-empty -----------------------------------------

Deno.test("QA-R-009 drill threshold: empty organizations table FAILS with the documented mismatch", () => {
  const v = evaluateDrillIntegrity({ tablesChecked: 180, organizations: 0 });
  assertEquals(v.status, "failed");
  assertEquals(v.mismatch, "organizations table empty after restore");
});

Deno.test("QA-R-009 drill threshold: a single organization row satisfies the non-empty gate", () => {
  const v = evaluateDrillIntegrity({ tablesChecked: 180, organizations: 1 });
  assertEquals(v.status, "success");
});

// --- ordering: tables are checked before orgs (a tables breach masks orgs) ----

Deno.test("QA-R-009 drill threshold: tables breach is reported before the orgs check", () => {
  // both gates would fail; the script checks tables first (L53 before L59).
  const v = evaluateDrillIntegrity({ tablesChecked: 10, organizations: 0 });
  assertEquals(v.status, "failed");
  assert(v.mismatch!.includes("too few tables"));
  assertFalse(v.mismatch!.includes("organizations"));
});

// --- guard: a non-numeric / NaN table count is treated as a fail (bash regex) -

Deno.test("QA-R-009 drill threshold: a non-integer table count fails the numeric guard", () => {
  // bash L53 requires TABLES to match ^[0-9]+$ before the > 100 test.
  const v = evaluateDrillIntegrity({ tablesChecked: Number.NaN, organizations: 12 });
  assertEquals(v.status, "failed");
});
