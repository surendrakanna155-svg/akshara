# Migration re-runnability convention (ICA-E3)

Every **new** SQL migration in `supabase/migrations/` must be **safely
re-runnable**: if a deploy fails partway through, re-applying the file must be a
no-op for the parts that already succeeded, never a hard error or a double-apply.

This is enforced automatically by the static guard
`supabase/functions/_shared/migration_rerunnability_guard_test.ts`
(`deno test --allow-read …`), in the same house style as `trunk_integrity_test.ts`.

## Grandfather cutoff

Enforced for every migration whose 14-digit version is **>= `20260920000060`**
(the ICA hardening batch). The 244 historical migrations before the cutoff are
**exempt** — they have already been applied to the live pilot, and rewriting
applied history to add guards would change checksums and risk ledger divergence.
The rule applies **going forward**, not retroactively.

## Rules (what "re-runnable" means here)

| # | Statement | Required form |
|---|-----------|---------------|
| R1 | `CREATE TABLE` | `CREATE TABLE IF NOT EXISTS …` |
| R2 | `CREATE [UNIQUE] INDEX [CONCURRENTLY]` | must carry `IF NOT EXISTS` |
| R3 | `ADD COLUMN` | `ADD COLUMN IF NOT EXISTS …` |
| R4 | `CREATE POLICY <name>` | precede with `DROP POLICY IF EXISTS <name> ON <table>` |
| R5 | `CREATE FUNCTION` / `CREATE PROCEDURE` | `CREATE OR REPLACE …` |
| R6 | `CREATE TRIGGER <name>` | `CREATE OR REPLACE TRIGGER …`, or precede with `DROP TRIGGER IF EXISTS <name>` |
| R7 | `ALTER TABLE … ADD CONSTRAINT` | guard it — either a `DO $$ … $$` block with a `pg_constraint` existence check (see `20260920000160`), or `DROP CONSTRAINT IF EXISTS` first, or express it as a `CREATE UNIQUE INDEX IF NOT EXISTS` (see `20260920000170`) |

Idiomatic guarded `ADD CONSTRAINT` (from `20260920000160`):

```sql
DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'attendance_records_student_id_fkey'
      AND conrelid = 'public.attendance_records'::regclass
  ) THEN
    ALTER TABLE public.attendance_records
      ADD CONSTRAINT attendance_records_student_id_fkey
      FOREIGN KEY (student_id) REFERENCES public.students (id)
      ON DELETE CASCADE NOT VALID;
  END IF;
END
$do$;
```

## Deliberate one-shot exception (rare)

A data migration that is **intentionally not idempotent** — e.g. a one-time money
re-scale that multiplies rows (see `20260920000060`, which does `× 100`) — must
declare itself with an explicit, auditable marker in a leading comment:

```sql
-- … NOT IDEMPOTENT BY DESIGN (it multiplies money ×100). …
```

(`NOT IDEMPOTENT BY DESIGN` or `@rerunnable: exempt`.) The guard records such a
file as a documented one-shot and skips the assertions for it. These run
**exactly once**, gated by the migration ledger; use the marker only when a guard
that silently skipped a partially-applied state would be *worse* than a hard,
one-shot correction.

## Why a guard and not a rewrite

The 244 historical migrations are already applied. The safe, correct fix for
"inconsistent idempotency guards" is to make the convention **mechanically
enforced on new work** and grandfather the past — not to edit applied history.
The guard is a pure static check (no DB, no network) and carries its own
non-vacuity tests (synthetic un-re-runnable SQL it must flag), so it cannot
silently rot into a no-op.
