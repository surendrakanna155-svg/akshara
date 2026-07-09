# Gap-Sweep Deploy & Live-Cert Checklist — 2026-07-09

**UPDATE (2026-07-09, socket opened): the TEST-TENANT rehearsal + live cert are
DONE; PROD is still PAUSED pending owner go.** Findings that change this plan:
- **Scope is the FULL backlog, not 4 migrations.** Prod `akshara_db` + edge are at
  `20260818` / `bcebbf12` (2026-07-01) — **44 migrations behind HEAD**
  (`20260819…20260866`). Deploying "this session's changes" = deploying the whole
  8-day backlog. Part B below must apply **all** pending migrations in order.
- **A real deploy blocker was caught + fixed:** `20260838000000` dropped `'all_staff'`
  from `comm_broadcasts_audience_check`, which is violated by existing prod rows
  (halts a sequential run mid-way). Fixed in place (details in
  `docs/FINANCE_FEE_REDUCTIONS_LIVE_CERTIFICATION.md` §2). The full backlog then
  applied cleanly on `akshara_tenant_test`.
- **`finance_fee_reductions` DB-level live cert PASSED** on `akshara_tenant_test`
  (non-destructive, rolled back) — RLS + CHECK + partial-unique all enforce live.
- **PROD untouched** (verified: `akshara_db` still `20260818`, no fee_reductions
  table; edge still `bcebbf12`).

**Remaining live step (PROD) is BLOCKED on owner go** (owner chose test-tenant-first).
Below is the exact recipe for the prod apply + edge deploy. Nothing here has
touched production.

**Governing law:** `AKSHARA_ENGINEERING_CONSTITUTION.md` Part 7B/8 · **Recipe
precedent:** `EOS_PHASE_B_B1_LIVE_DEPLOY_REPORT.md` (deploy), the
`scripts/qa/live_cert_*.py` harnesses (cert), `COM4_CRON_ACTIVATION_RUNBOOK.md`
(COM-4), `OFFSITE_BACKUP_R2_RUNBOOK.md` (R2).

**VPS discipline:** shared production box (co-hosts velora-salon / n8n / redis) —
**Akshara-only, never touch the others.** Prod tenant DB = `akshara_db`;
non-destructive cert tenant = `akshara_tenant_test`. Connect with
`ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46 '<cmd>'` (needs
`dangerouslyDisableSandbox: true`).

---

## Part A — What this session added (the deploy payload)

| Artifact | Kind | Status in repo | Deploy target |
|---|---|---|---|
| `20260863000000_finance_fee_reductions.sql` | migration | committed | tenant DB (schema) |
| `20260864000000_inventory_replacement_parent_write_scope.sql` | migration | committed | tenant DB (RLS) |
| `20260865000000_operations_hub_item_actions.sql` | migration | committed | tenant DB (table+RLS) |
| `20260866000000_student_profile_guardian_student_read_rls.sql` | migration | **new (this session)** | tenant DB (RLS read policy) |
| Gap-wave backend handlers/routes (P0×3 + P1×7) | edge code | committed | `akshara-edge` function |
| COM-4 internal-cron token path (`communication_cron_auth.ts`) | edge code | committed (staged) | `akshara-edge` + secret |

All four migrations are additive / non-destructive (new table, new RLS policies,
new partial-unique indexes). `20260866` only ADDs student-scope `FOR SELECT`
policies; it alters no existing policy. Migration numbering is contiguous and
collision-free (verified `20260863..20260866`, no duplicate on disk).

---

## Part B — Deploy sequence (run when socket is open)

> Order matters: **migrations first** (so the new endpoints have their tables),
> then the edge function, then health verification. Every step is idempotent or
> re-runnable.

1. **Pre-flight (read-only).**
   - `ssh … 'psql "$AKSHARA_DB_URL" -c "select 1"'` → confirms tenant DB reachable.
   - `curl -s https://<edge>/health` → capture the currently-deployed `version`
     (the git SHA) so you can prove the version flips after deploy.
   - `git rev-parse HEAD` locally == the SHA you intend to ship.

2. **Apply migrations to the PROD tenant (`akshara_db`), in number order.**
   Preferred: the repo's standard migration runner (same one prior waves used —
   do NOT hand-run raw SQL if a runner exists). If applying by hand, wrap in a
   transaction and apply `20260863 → 20260864 → 20260865 → 20260866` in order.
   Each is additive; a mid-sequence abort leaves earlier ones applied and safe.
   - Verify after: `\d+ finance_fee_reductions` shows the table + 2 partial
     unique indexes + RLS enabled/forced; `\dp student_profiles` /
     `\dp student_guardians` show the new `*_student_read` SELECT policies.

3. **Deploy the edge function to `akshara-edge`** (Supabase functions deploy per
   the B1 recipe). This ships all gap-wave handlers + the COM-4 auth path.

4. **Post-deploy health smoke (all must be green):**
   - `GET /health` → `200`, `version` == HEAD (proves the new code is live).
   - `GET /health/ready` → `200 {"database":true}`.
   - `GET /health/storage` → `200 reachable:true`.
   - `GET /health/backup` → `200 status:ok` (nightly fresh; see Part D).

5. **COM-4 activation (only if the owner approves it this cycle)** — follow
   `COM4_CRON_ACTIVATION_RUNBOOK.md` exactly: set `INTERNAL_CRON_TOKEN` server
   secret, restart the function, install the client-side cron. Until the secret
   is set the path safely 401s (documented "safe expected state"). **Owner-gated.**

6. **Off-site backup activation (only when R2 creds are supplied)** — follow
   `OFFSITE_BACKUP_R2_RUNBOOK.md` (set `RCLONE_REMOTE`, verify a 3-2-1 copy).
   **Owner-gated on R2 credentials.**

**Rollback:** the edge function redeploys to the prior SHA in one command. The
migrations are additive — no down-migration is needed for pilot; if a policy
must be pulled, `DROP POLICY … ` the specific new policy (they are named).

---

## Part C — Live-cert checklist: `finance_fee_reductions` (NON-DESTRUCTIVE)

Run on **`akshara_tenant_test`** (never `akshara_db`), inside a transaction that
is **rolled back** at the end — nothing is persisted. This proves live what is
today only pattern-matched. Author as `scripts/qa/live_cert_fee_reductions.py`
following the existing `live_cert_*.py` harness shape (real auth, real DB, real
RBAC, ROLLBACK). Each check below has a concrete assertion:

**C1 — RLS isolation (school scope).** With `app_current_scope()='school'` set to
school A, a `SELECT`/`UPDATE` on a school-B row returns/affects **0 rows**;
cross-tenant returns 0. A `parent`/`student` scope sees 0 (policy is
school-scope `FOR ALL` only). → *the `finance_fee_reductions_school_scope`
USING + WITH CHECK holds.*

**C2 — CHECK constraints reject bad rows** (each must raise):
   - `source_kind='scholarship'` with `discount_rule_id` set → `source_ck` violation.
   - `reduction_kind='percent'` with `percent=0` or `percent>100` → `value_ck`.
   - `reduction_kind='fixed'` with `fixed_amount<=0` → `value_ck`.
   - both `percent` and `fixed_amount` set → `value_ck`.
   - `applied_amount < 0` → `applied_nonneg_ck`.
   - `status` / `source_kind` / `reduction_kind` outside their enum → CHECK.

**C3 — Partial-unique idempotency.** Two live (`pending`/`approved`) reductions
for the SAME `(invoice_id, scholarship_id)` → the 2nd raises unique-violation on
`uq_finance_fee_reductions_live_scholarship`; same for the discount index. A
`reversed`/`rejected` row does NOT block a new live one (partial predicate).

**C4 — Separation of duties (maker≠checker).** Approving with
`approved_by == created_by` is rejected server-side (mirrors FIN-D4). Approval by
a distinct authorized user succeeds.

**C5 — Lockstep + clamp (the money invariant), FOR UPDATE.** On approve of a
reduction larger than the invoice's current outstanding:
   - `applied_amount` == the CLAMPED value (== prior outstanding, never more),
   - `invoice.outstanding_amount` and `finance_student_accounts.outstanding_amount`
     move by the **same delta** (lockstep),
   - payable never goes negative.
   Reverse → both move back by the SAME `applied_amount`; reversing twice is a
   no-op (no double-refund). Run the approve/reverse under concurrent sessions
   (two `FOR UPDATE` txns) to prove the row-lock serializes them.

**C6 — Re-affirm RLS + backup (regression).** Re-run the QA-B cross-tenant RLS
probe set (all-pass, zero leaks — already green this session pre-deploy) plus
`GET /health/backup → 200` after deploy.

**Acceptance:** C1–C6 all green on `akshara_tenant_test`, transaction rolled
back, then write `docs/FINANCE_FEE_REDUCTIONS_LIVE_CERTIFICATION.md`.

---

## Part D — Blockers summary (why this is staged, not done)

| Blocker | Needs | Owner action |
|---|---|---|
| Live apply + live cert + health smoke | authenticated SSH master | open `~/.ssh/akshara-cm.sock` |
| COM-4 cron activation | `INTERNAL_CRON_TOKEN` secret + approval | approve + provide/rotate token |
| Off-site R2 (3-2-1) | R2 credentials | supply `RCLONE_REMOTE` creds |

Everything else — code, migrations, cert design — is complete and green locally.
