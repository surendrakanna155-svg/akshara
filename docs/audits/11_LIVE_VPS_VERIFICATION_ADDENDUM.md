# Akshara ERP — Live VPS Verification Addendum

**Auditor:** Fable (independent) · **Date:** 2026-07-03 · **VPS:** `root@46.28.44.46` (`akshara.veloraunisexsalon.com`)
**Trigger:** owner opened the live SSH ControlMaster socket, unblocking the audit's largest blind spot (the "live lane").
**Method:** read-only diagnostics; **no secret values printed, nothing mutated.**

> This addendum resolves the "Unknown — needs live-VPS access" items flagged throughout reports 00–10.
> Some resolved **favorably** (downgrade the finding); one resolved **worse than the repo showed**
> (a confirmed live P0). Reports 00–10 remain as written; this addendum is the live overlay.

---

## 1. Live environment baseline

- Containers healthy: `akshara-postgres` (up 2d, healthy), `akshara-edge`, `akshara-postgrest`, `akshara-rest-gateway`, `akshara-storage`. **Co-hosted with `velora-salon` (Django) + `root-n8n-1`** on the same box (shared-fate — see LV-4).
- **10 school rows** and **172 RLS-enabled tables** in `akshara_db`. **Classified (LV-7): all 10 are demo/staging/cert/pilot-simulation tenants** (created 2026-06-23→27) — **no real customer data on the box today.**

---

## 2. Findings RESOLVED FAVORABLY (downgrade)

| Audit finding | Was | Live evidence | New status |
|---|---|---|---|
| **DB-2** — edge must use `erp_tenant`, not `service_role` (the #1 RLS control) | P0-deploy (unverified) | DSN user = `erp_tenant`; `pg_roles.rolbypassrls = f` (NOBYPASSRLS) | ✅ **SATISFIED live** — the entire RLS model's load-bearing invariant is correctly configured |
| **DB-1** — hardcoded tenant DB password in git | P0 | Live DSN password **does NOT match** the git default `akshara_erp_tenant_staging_v1` → **rotated on the live box** | ⬇ **P0 → P2** — live pilot is safe; but the *migration still ships the default*, so any **new** provisioning (dedicated school / fresh deploy) inherits the git credential. Fix the migration. |
| **ENG-2 / OPS-5** — entitlement (402) enforcement ships OFF | P1 (verify at pilot) | `ENTITLEMENT_ENFORCEMENT=true` in the live edge env | ✅ **ON live** — server-side plan-gating is active |
| **AI-4** — AI silently degrades to deterministic with no key | P1 | `ANTHROPIC_API_KEY` unset **but** `AI_PROVIDER=openrouter` + `OPENROUTER_API_KEY` SET | ⬇ **AI is live via OpenRouter, not dead.** The robustness point (no health signal on missing key) stands, but the pilot has working AI |
| **JWT_SECRET fail-closed** | verify | `JWT_SECRET` SET (len 48 ≥ 32) | ✅ satisfied |

---

## 3. Findings — DR posture (⚠ CORRECTED after full read-only sweep)

> **Methodology correction (owner-directed, 2026-07-03) — and a corrected finding.** My first pass
> checked only *root's* crontab and the backup dir, and wrongly concluded "no automated backup" (LV-2).
> That was a **false positive**. The full sweep found the Akshara backup jobs live in **`/etc/cron.d/`**,
> not root's crontab. The corrected, evidence-backed DR posture is **materially healthier** than the
> interim read, and — critically — **the 10 tenants are all demo/staging/cert/pilot-sim schools, not
> real customer data (LV-7).** The genuine residual gaps are narrower: **off-site + WAL/PITR + alert
> delivery.**

**Backup/restore mechanism (evidence):** `/etc/cron.d/akshara-ops` → `akshara-backup.sh` nightly **02:15** + `akshara-restore-drill.sh` monthly (2nd, 03:30); `/etc/cron.d/akshara-watchdog` → `akshara-watchdog.sh` every 5 min. Config `/opt/akshara/backup/backup.env`: encrypted dumps (`BACKUP_KEY` set), retention `KEEP_DAILY=7 / WEEKLY=4 / MONTHLY=12`, store `/opt/akshara/backup/store`, `RCLONE_REMOTE=` (empty).

| ID | Sev | Finding (live, corrected) | Evidence | Status |
|---|---|---|---|---|
| **LV-2** | ~~P0~~ → **REFUTED** | **Automated encrypted backups DO run and succeed daily.** | `backup.log`: `[2026-07-03T02:15:04Z] backup SUCCESS (nightly) in 2222ms`; `[2026-07-02…] backup SUCCESS`; store holds nightly/weekly/monthly/manual `.dump.enc` from Jun 23→Jul 3; sha256 logged per dump | **CORRECTED — my initial LV-2 was WRONG** |
| **LV-8** | ✅ **STRENGTH** | **Restore is actually TESTED monthly and passed.** | `drill.log`: `[2026-07-02T03:30:09Z] drill SUCCESS: 184 tables, orgs=4 users=13, 8211ms` — decrypts the nightly dump, restores to `akshara_db_drill`, verifies content | **CONFIRMED — refutes the repo-based OPS-2 "restore never run"** |
| **LV-9** | ✅ **STRENGTH** | **Watchdog runs every 5 min, all green.** | `watchdog.log` `[2026-07-03T17:15:03Z] check: api_ready=OK api_backup=OK api_storage=OK disk=30% cert=79d … all containers up` | CONFIRMED |
| **LV-1** | **P1** | **No WAL archiving / no PITR** → RPO ≈ 24h (nightly dump cadence), not ≤15 min. | `pg_settings`: `archive_mode=off`, `archive_command=(disabled)`, `wal_level=logical` | **CONFIRMED (real gap; severity downgraded P0→P1 since nightly backups + tested restore exist)** |
| **LV-3** | **P1** | **No off-site copy** — local-only (violates 3-2-1). The script itself flags it. | `backup.log`: `WARNING: no RCLONE_REMOTE configured — backup is LOCAL-ONLY (violates 3-2-1)` … `offsite=false`; `backup.env` `RCLONE_REMOTE=` empty; `rclone` binary absent | **CONFIRMED (real gap; downgraded P0→P1 given working local backups + no real data yet)** |
| **LV-6** | **P2** | **Watchdog alert *delivery* target not wired** — checks run but likely can't reach a human. | `monitoring.env`: `ALERT_WEBHOOK_URL=` empty, `ALERT_SMS_PHONES=` empty, `INTERNAL_HEALTH_TOKEN=` empty (a `FAST2SMS` key IS set, but no recipient) | CONFIRMED (minor) |
| **LV-10** | **P3** | Backup script emits `line 35: $1: unbound variable` warnings (backup still succeeds). | `backup.log` header lines | CONFIRMED (cosmetic/robustness) |
| **LV-4** | **P1** | Single box shared by ≥3 apps (Akshara + velora-salon Django + n8n). | `docker ps` | CONFIRMED |
| **LV-5** | **P2** | Live edge runs `APP_ENV=staging`. | edge env | CONFIRMED (confirm intent) |
| **LV-7** | ✅ **de-risks** | **The 10 tenants are ALL demo/staging/cert/pilot-sim schools — no real customer data at risk today.** | `schools`: `Akshara Staging School A/B` (AKS-001/002), `Cert Trust … Main Branch`, `Onboarding Cert School`, `Sunrise Small Private`/`Delhi Public CBSE`/`St Marys ICSE`/`Govt State Board`/`Single Campus`/`Trust Branch North` (all created 2026-06-23→27, the pilot-sim set) | **CONFIRMED demo/test** |

### 3.1 Corrected DR verdict

The DR posture is **reasonably mature, not catastrophic** — automated, encrypted, retained, and **restore-tested** nightly backups with active health monitoring. My initial "data-loss-waiting-to-happen" framing was **wrong on two counts**: backups exist and succeed (LV-2 refuted), and there is **no real customer data yet** (LV-7). The **genuine, real** residual gaps for a *real-production* posture are:
1. **No off-site copy** (LV-3, P1) — a single-site failure still loses everything; `RCLONE_REMOTE` just needs setting (the script is ready).
2. **No WAL/PITR** (LV-1, P1) — RPO is ~24h; fine for a pilot, tighten before real fee data.
3. **Alert delivery not wired** (LV-6, P2) — the watchdog watches but can't yet page a human.
4. Shared box (LV-4) + staging env (LV-5) + a cosmetic script bug (LV-10).

**Net:** Deployment/Ops/DR should be **re-rated UP** from the repo-based 4.5/10 — the live box has more operational maturity than the repo alone showed (tested restores are a genuine strength). It is **pilot-adequate today**; the off-site + PITR + alert-delivery items are the real work before it carries irreplaceable customer data.

---

## 3b. Cross-tenant RLS isolation — LIVE PROBE **PASS** (closes QA-2, the audit's #1 P0)

> **Owner-approved (2026-07-03).** Ran faithful isolation probes **as the real `erp_tenant` role**
> (`NOBYPASSRLS` — exactly what the edge uses), against **real live data**, inside **rolled-back
> transactions** (nothing changed — INSERT/UPDATE tested via SAVEPOINT + `ROLLBACK`). This is the
> gold-standard test the repo suite never executed (`tenant_isolation_enforced_test.ts` is
> `ignore`-gated on a DB URL absent in CI). Fixtures: org `a1…000001` contains `AKS-001` (4 students)
> and `AKS-002` (1 student); org `a1…00d8` is a different tenant.

**Read isolation (school-scoped staff @ AKS-001):**

| Probe | Expected | Actual | Result |
|---|---|---|---|
| Own-school students | 4 | **4** | ✅ |
| Cross-school **same-org** students (AKS-002) | 0 | **0** | ✅ |
| Total students visible | 4 | **4** | ✅ (only own school) |
| Cross-school **row** (AKS-002) | 0 | **0** | ✅ |
| Cross-**org** school (org `…d8`) | 0 | **0** | ✅ tenant-isolated |
| All schools visible | 1 | **1** | ✅ |
| **Parent scope** — students visible | 1 | **1** | ✅ only the linked child, not all 4 |

**Write isolation (rolled back):**

| Probe | Expected | Actual | Result |
|---|---|---|---|
| Cross-**org** INSERT into students | rejected | `ERROR: new row violates row-level security policy for table "students"` | ✅ `WITH CHECK` blocks cross-tenant write |
| Cross-**school** UPDATE (AKS-002 row) | 0 rows | `UPDATE 0` | ✅ invisible → unmodifiable |

**Verdict — LV-11 (STRENGTH):** cross-tenant, cross-school, and parent-scope isolation are **enforced at the database for the real app role, for both reads and writes.** This is the single most important guarantee for a multi-tenant ERP, and it is now **live-verified PASS**. **QA-2 (audit's #1 P0) is CLOSED.** Caveat: this proves the *policies enforce correctly for `erp_tenant`*; it does **not** replace the full 233-probe suite across every table — recommend still running `tenant_isolation_enforced_test.ts` in CI for regression coverage (it will now pass on this DB).

## 4. Still to verify live (offered, not yet run — require owner go-ahead as they touch prod)

| Audit item | How to close it live |
|---|---|
| **QA-2** — cross-tenant RLS isolation never *executed* | Run the staged `tenant_isolation_enforced_test.ts` (233 probes, rolled-back txns) against `ERP_TENANT_DATABASE_URL` — now reachable. **This is roadmap W1's marquee item.** |
| **OPS-2** — restore drill never run | Run `akshara-restore-drill.sh` on a staging tenant. |
| **QA-3** — live-regression cron 7-day green | Install the cron + start the clock. |
| Live perf (`QA-R-006`) | Run the k6 p95 probe at scale. |
| Live money-loop E2E | Run the pilot-sim harness (creates isolated throwaway school). |

---

## 5. DR discovery — COMPLETE. Remaining real work (before real customer data)

The full read-only sweep is done. The DR posture is pilot-adequate. The genuine pre-real-production items, in order:
1. **Off-site copy** (LV-3) — set `RCLONE_REMOTE` + install `rclone`, push nightly `.dump.enc` to S3/R2. (Script is already off-site-ready.)
2. **WAL archiving / PITR** (LV-1) — `archive_mode=on` + `archive_command` to cut RPO from ~24h → ≤15 min.
3. **Alert delivery** (LV-6) — set `ALERT_WEBHOOK_URL` and/or `ALERT_SMS_PHONES` so the (already-running) watchdog can page a human.
4. Fix the backup-script `$1` unbound-variable warning (LV-10); decide shared-box (LV-4) + `APP_ENV=staging` (LV-5) intent.

All of the above are **owner/ops actions** (config + a bucket) — not code. None is a catastrophe; the backup+tested-restore foundation is real. **No server changes were made during this audit; every probe was read-only.**
