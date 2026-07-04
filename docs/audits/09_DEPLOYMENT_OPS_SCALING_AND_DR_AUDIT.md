# Akshara ERP — Deployment, Operations, Scaling & DR Audit

**Auditor:** Fable (independent) · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Scope:** the live VPS deployment, backup/DR reality vs plan, monitoring, multi-tenant scaling, commercial/operational readiness.
**Confidence:** High on repo/config evidence; Medium on live-VPS state (not reachable from the audit environment).

---

## 1. Executive summary

1. **The pilot backend is self-hosted, single-node, via docker-compose** — not Supabase-cloud. `deploy/akshara-vps/docker-compose.akshara.yml` runs: `akshara-postgres` (Supabase Postgres 17.6, bound `127.0.0.1:5433`), `akshara-postgrest` + `akshara-rest-gateway` (nginx, internal-only), and `akshara-edge` (Deno running `api/index.ts`). Clean, minimal, sensible for a pilot.
2. **The multi-tenant model runs on ONE Postgres container on ONE VPS.** Shared-DB + RLS is real and correct, but there is currently a single node behind every school. The "Shared SaaS vs Dedicated Infrastructure + School Registry + migration-fleet-runner" model exists as a **design** (`DEPLOYMENT_MODEL_AND_DR_PLAN.md`), not as code.
3. **DR targets are aspirational vs the shipped reality.** The plan states **RPO ≤15 min / RTO ≤1h (Dedicated), ≤2h (Shared)** via continuous WAL + nightly snapshot + off-site copy + monthly restore drill. But per the team's own `IDEAS_BACKLOG.md`: **off-site is not provisioned (offsite=false, backups local-only), WAL/PITR is not wired (RPO is ~24h today, not 15min), and alert sinks are log-only** (no `ALERT_WEBHOOK_URL`/`ALERT_SMS_PHONES` configured).
4. **Backup/restore + monitoring scripts are real and shipped** (`akshara-backup.sh`, `akshara-restore.sh`, `akshara-restore-drill.sh`, `akshara-watchdog.sh`, cron installers) — but the **live drill has never run** (it's the QW8-deferred `QA-R-009` Track-B leg, blocked on the SSH socket + tenant DB).
5. **Commercial readiness is deliberately partial and honest.** Billing/quotas/marketplace are Phase-2 (O6); white-label tiers Phase-2 (O10); the pilot runs on entitlement-gating + manual invoicing. But **server-side entitlement enforcement ships OFF by default** (ENG-2) — so even the plan-gating that *is* built won't fire unless an env flag is set.
6. **Single-VPS = single point of failure with no documented failover** for the pilot; acceptable for one pilot school, not for the "thousands of schools" the charter asks us to imagine.

---

## 2. Findings

| ID | Sev | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| OPS-1 | **P0 (pilot)** | Real RPO is ~24h (nightly), not the documented ≤15 min — WAL/PITR not wired; off-site copy not provisioned (local-only) | `IDEAS_BACKLOG.md` "Batch 7 follow-ups"; `DEPLOYMENT_MODEL_AND_DR_PLAN.md` targets | Wire WAL archiving + an off-site bucket (S3/R2 + rclone) before pilot go-live, or explicitly accept a 24h RPO in writing and tell the school. A school losing a day of fee receipts is a trust-ending event. |
| OPS-2 | **P0 (pilot)** | The live backup→restore→integrity drill has never run | `QA-R-009` Track-B blocked; scripts exist but unexercised | Run the drill on a staging tenant before pilot. An untested restore is not a backup. |
| OPS-3 | **P1** | Alert sinks are log-only — watchdog alerts don't reach a human | `IDEAS_BACKLOG.md`; `monitoring.env.example` (`ALERT_WEBHOOK_URL`/`ALERT_SMS_PHONES` unset) | Set a webhook/SMS sink before pilot; an alert nobody sees is not monitoring. |
| OPS-4 | **P1** | Single-node VPS = SPOF, no failover documented for the pilot | `docker-compose.akshara.yml` (one node) | Document the manual-recovery runbook + acceptable downtime for the pilot; plan the HA/replica story before multi-school GA. |
| OPS-5 | **P1** | Server-side entitlement/plan enforcement OFF by default (ENG-2) | `entitlement_enforcement.ts` | Set `ENTITLEMENT_ENFORCEMENT=true` in live `.env`, or accept that plan gating is dark. |
| OPS-6 | **P1** | Hardcoded tenant DB password in a committed migration (DB-1) — an operational secret in git | `20260610100000…:13` | Rotate before pilot; move to vault. |
| OPS-7 | **P2** | The "School Registry + migration-fleet-runner + Shared↔Dedicated move" scaling model is design-only | `DEPLOYMENT_MODEL_AND_DR_PLAN.md` vs single compose file | Fine for the pilot; build the registry + fleet runner before onboarding the 2nd–Nth school. |
| OPS-8 | **P2** | No off-repo evidence of error tracking / metrics (Sentry/Prometheus) wired live | `IDEAS_BACKLOG.md` (deferred, vendor accounts) | Wire a DSN + basic metrics before scale; blind production is a scaling liability. |

---

## 3. Scaling verdict (what breaks, and when)

- **1 school (pilot):** the current single-node stack is adequate **once OPS-1/2/3 are closed**. The app logic is sound.
- **~10–100 schools (shared node):** RLS shared-DB scales reasonably on one strong Postgres box, but: (a) the single Deno isolate's 10-conn pool + shared-fate becomes a real contention risk (ENG-6); (b) N+1 report loops (ENG §3) slow the biggest schools; (c) no HA/replica = every school shares one SPOF. Needs load testing + a read-replica story.
- **500–5,000 schools:** requires the **School Registry + migration-fleet-runner + Shared/Dedicated split** that is currently design-only (OPS-7), plus horizontal edge scaling, connection pooling (PgBouncer), per-tenant resource limits, and real observability (OPS-8). **The architecture *can* get there** (the design is coherent), but essentially none of the horizontal-scale machinery is built yet.

## 4. Commercial & operational readiness

- **Honest and appropriately staged:** billing/quotas/white-label = Phase-2; pilot = entitlement-gating + manual invoicing. Good discipline.
- **Gaps for a *commercial* (not pilot) launch:** in-product billing, usage metering, the entitlement enforcement actually turned on (OPS-5), white-label tiers, off-site DR (OPS-1), monitoring/alerting reaching humans (OPS-3), and a tested restore (OPS-2).

## 5. Genuine strengths

- Clean, minimal, reproducible single-node deployment recipe with health checks and internal-only service exposure (Postgres/PostgREST not host-published).
- Real backup/restore/watchdog scripts + cron installers + a documented DR *plan* with sensible RPO/RTO targets and a Shared/Dedicated model.
- Correct security posture in compose (Postgres bound to loopback, gateway internal-only).
- Deliberate, documented Phase-2 deferral of monetization — not over-promised.

## 6. Unknowns (need live-VPS access)

- Actual live `.env` (is `ENTITLEMENT_ENFORCEMENT` on? is the tenant password rotated? is an AI key set?).
- Whether WAL/off-site/alert-sinks were configured on the live box despite the repo defaults.
- Real performance at scale (no live k6 run has executed — `QA-R-006` Track-B blocked).
