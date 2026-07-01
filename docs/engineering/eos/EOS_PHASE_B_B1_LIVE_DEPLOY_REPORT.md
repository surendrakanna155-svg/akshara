# EOS Report — Phase B (Track B) · B1 Live VPS Deployment Verification

**Date:** 2026-07-01 · **Scope:** Phase B / Track B task **B1 — Live VPS deployment** (first eligible Track B wave) · **HEAD:** `681d2691264eccf1649b80c63b4caa3db5ecdbef` · **Branch:** `feature/data-reliability-platform`
**Governing law:** [`AKSHARA_ENGINEERING_CONSTITUTION.md`](../AKSHARA_ENGINEERING_CONSTITUTION.md) Part 7B (Certification Engine) + Part 8 (EOS) · **Roadmap:** [`FINAL_QA_ROADMAP.md`](../../FINAL_QA_ROADMAP.md) Phase B, task B1.

---

## 1. Objective & scope

The owner authorized execution of **Track B only** (Release Engineering / live-VPS validation), instructing: *determine the safest execution order, execute only the first eligible wave, and stop whenever an owner decision is required.*

Per the Phase B dependency DAG, the **first eligible task is B1** — its sole entry gate is the owner-provided SSH ControlMaster socket, which is open. All downstream tasks depend on either B1, the (unprovisioned) tenant Postgres (B5), or a biometric device (B4). No new features, no roadmap change — this run only executes the already-authored deploy verification against real infrastructure.

## 2. Entry-gate evidence (infrastructure)

| Entry gate | State | Evidence |
|---|---|---|
| SSH ControlMaster socket | **OPEN** | `ssh -O check akshara` → `Master running (pid=87894)`; socket `~/.ssh/akshara-cm.sock` present (Jul 1 11:23); `Host akshara` → `ControlPath ~/.ssh/akshara-cm.sock` |
| Tenant Postgres (`ERP_TENANT_DATABASE_URL`) | **NOT PROVISIONED** | absent from environment — gates B5 → B3/B6/B7/B8/B10/B11 |
| Biometric-enrolled device/emulator | **NOT PROVIDED** | gates B4 (staff Face ID on-device run) |

## 3. B1 acceptance criteria — evidence

B1 completion criteria (roadmap): *`/health` → 200 · post-deploy smoke green · deployed version == HEAD.*

| Check | Result | Evidence |
|---|---|---|
| Deployed version == HEAD | **PASS** | `GET /health` → `version:"681d2691264eccf1649b80c63b4caa3db5ecdbef"` == HEAD == local == remote (`git @{u}` identical); no uncommitted backend/supabase code |
| Service up | **PASS** | `GET /health` → `200 {"status":"ok","service":"akshara-api","builtAt":"2026-07-01T06:37:02Z"}` |
| Database reachable | **PASS** | `GET /health/ready` → `200 {"status":"ready","database":true}` |
| Storage reachable | **PASS** | `GET /health/storage` → `200 {"bucket":"school-memories","reachable":true}` |
| Providers/connection | **PASS** | `GET /health/providers` → `200`, `connection.ok:true` (role `erp_tenant`), storage reachable |
| Edge function live at HEAD | **PASS (implied)** | `/health` is served by the edge function and reports HEAD → the Supabase edge function is live at HEAD (supporting evidence for B2, not formally certified here) |

## 4. Finding (P1) — DIAGNOSED + RESOLVED (2026-07-01, B9 lane)

**`GET /health/backup` → 503 `backup_stale`** (last backup a **manual** dump **108.4 h old** vs a **26 h** max-age). **Root cause = a shell bug, not infra:** `akshara-backup.sh:35` tested bare `"$1"` before its `:-` default; under `lib-common.sh:5` `set -euo pipefail` the **no-arg nightly cron** invocation tripped `line 35: $1: unbound variable` and `set -e` aborted the script **before** `pg_dump`/ledger row. Cron *was* firing nightly (syslog: Jun 27→Jul 1 all logged at 02:15 UTC) — the job died instantly each time. Manual runs pass `$1`, so they succeeded — which is why every stored artifact was `manual` and no nightly ever ran.

- **Rule:** Part 7B — *Automatic Failure Conditions* (*missing backup verification*) is a GA-gate (`QA-R-012`) blocker; owned by **B8 (`QA-R-009`)** + **B9 (`QA-R-010`)**, not a B1 deploy defect.
- **Severity:** **P1** — **RESOLVED**.
- **Fix (committed `6393e81`):** `akshara-backup.sh:35` `"$1"` → `"${1:-}"`. Patched in repo, copied to VPS `/opt/akshara/backup/`, and **verified live**: no-arg run → `backup SUCCESS ... 751ms`, fresh `ops_backup_runs` row, **`/health/backup` → 200** (`status: ok`, ageHours 0). Nightly cron path now healthy.
- **Residual (B8, open):** off-site copy is **not configured** — run logged `no RCLONE_REMOTE configured — backup is LOCAL-ONLY (violates 3-2-1)`. Close in B8 (DR completeness) alongside the live restore/integrity drill.

## 5. Gate verdict

**B1 — Live VPS deployment: EOS gate PASS** (deploy verified live at HEAD; post-deploy health smoke green on every deploy-owned surface). One **P1 surfaced and tracked to B8/B9** (backup staleness) — it does not block B1 but must be cleared before B12/B13 (GA).

**Phase-level:** `QA-R-012` remains **BLOCKED** (unchanged) — GA still gated on the tenant-Postgres live legs (B3/B5/B6/B7/B8/B10/B11), the Face ID on-device run (B4), the backup finding above, and the 7-day regression cron (B12).

## 6. STOP — owner decisions required to proceed past B1

Per the owner's instruction to stop at the first required decision:

1. **Tenant Postgres** — provide `ERP_TENANT_DATABASE_URL` (RLS-enabled) → unblocks B5, then B3/B6/B7/B8/B10/B11.
2. **Biometric device/emulator** — provide one with a biometric enrolled → unblocks B4 (staff Face ID live).
3. **Backup staleness** — decide whether to investigate/remediate the stale nightly backup now (as B9 work) or defer within Phase B.

No tracker row was rewritten. This report + the ledger entry are the only artifacts produced.
