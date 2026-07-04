# Akshara ERP — Global Red Team Framework

**Status:** Strategy / design-only (no code) · **Author:** Fable · **Date:** 2026-07-03
**Grounded in:** the Fable Final Audit (`docs/audits/`) — the Red Team's job is to *break* what the audit
verified and *confirm* what it flagged. **Maps to:** Master Roadmap **Phase 4** (`P4-RT-1`) → **Phase 5** (`P5-FIX-1`).
**Precondition:** run **after** the Master-Roadmap Phase-0 truth pass — a Red Team is only as valuable as the honesty of the claims it attacks.

> **Mission.** One adversarial, perspective-diverse assault on Akshara before it carries real schools.
> Assume a motivated attacker, a careless clerk, a flaky network, a hostile tenant, and a bad day for
> the server — simultaneously. Find what breaks; prove it with evidence; gate GA on the fixes.

---

## 1. Domains (attack surfaces)

| # | Domain | Core question |
|---|---|---|
| 1 | **Security** | Can anyone authenticate, escalate, or read/write outside their permission? |
| 2 | **Multi-tenant isolation** | Can school/org A ever read or write school/org B's data — under concurrency, replay, or crafted scope? |
| 3 | **Money integrity** | Can any sequence create a duplicate/lost/incorrect financial transaction, or bypass maker-checker? |
| 4 | **AI abuse** | Can the AI be injected, made to leak in-scope-but-sensitive data, or run up unbounded cost? |
| 5 | **UX failures** | Can a user lose work, be misled by stale/wrong-language data, or be blocked with a raw error? |
| 6 | **Workflow failures** | Can a critical workflow (admission→enrollment, marks→publish, fee→receipt, promotion→TC) be left half-done or corrupted? |
| 7 | **Operational failures** | Do backups, alerts, health checks, and scheduled jobs actually work when needed? |
| 8 | **Disaster recovery** | Can we restore to a known-good state within RTO, with integrity, from off-site? |
| 9 | **Data corruption** | Can partial writes, bad migrations, or constraint gaps leave inconsistent data? |
| 10 | **Concurrency** | Do races (double-submit, dual-cashier, simultaneous edits, offline replay) corrupt state? |
| 11 | **Performance** | Do large rosters/marks/dashboards/reports/search degrade past SLA or exhaust the pool? |
| 12 | **Human error** | Does a mistaken tap, wrong field, or skipped step cause irreversible or silent harm? |

---

## 2. Per-domain attack playbook (seeded from audit findings)

Each domain lists representative attacks; the Red Team must extend them.

**1 Security** — forge/replay JWT; expired/revoked token still works (audit SEC-4 unproven); role→permission mapping wrong; a route with no permission gate (audit ENG-5); demo/mock auth reachable in a mis-built release (SEC-1/9); PII in plaintext prefs (SEC-3); missing cert pinning MITM (SEC-5); raw `error.message` disclosure (SEC-6); SECURITY DEFINER trusts caller args (DB-4).

**2 Multi-tenant isolation** — cross-school read/write with crafted `school_id`; org-scope reading raw memberships; parent seeing another child; **concurrent** multi-tenant writes bleeding; edge using `service_role` instead of `erp_tenant` (audit DB-2 — verify at deploy). *(Audit live-verified the single-session case (LV-11); Red Team attacks the concurrent + crafted-scope case.)*

**3 Money integrity** — retry a fee collection without idempotency key → duplicate (audit REL-1); two cashiers collect the same invoice simultaneously → lost-update (audit ENG-1, the row_version fix must hold); self-approve a refund/concession (maker-checker bypass); offline collect mints a receipt before sync (audit R1); negative/overflow amounts; day-close then back-date.

**4 AI abuse** — prompt-injection via school/student names or free text (audit AI-5); coax the copilot to reveal in-context data beyond intent; loop requests to exhaust spend (no cap — AI-1); force a hang with no timeout (AI-3); no-key silent degradation misleads (AI-4); make the model fabricate a number (should be blocked by determinism-first).

**5 UX failures** — kill the app mid-entry on the 2 screens without drafts (audit REL-3); relaunch-while-online doesn't drain outbox (REL-4); stale offline data shown as current with no freshness chip (REL-7/UX-3); raw enum error reaches the user; wrong-language parent comms; dead/backend-less surface reachable (ENG-3).

**6 Workflow failures** — interrupt admission between approve and enroll; publish marks with an absent student mis-counted; promotion commit half-applied; TC issued with unpaid dues; broadcast partially delivered.

**7 Operational** — does the watchdog alert actually reach a human (audit LV-6)? do scheduled jobs run? does the backup cron succeed (LV-2 verified) and off-site push exist (LV-3)?

**8 DR** — restore the latest backup to a clean box; verify integrity == source; measure RTO; confirm off-site copy is usable (not just local); WAL/PITR to a point in time (after P0-INFRA-2).

**9 Data corruption** — force a partial write mid-transaction; a migration applied twice; a constraint gap (pre-2026-08-14 duplicate admission#, audit DB-7); a ledger row mutated by service_role (DB-5).

**10 Concurrency** — double-submit every mutation; dual-cashier; simultaneous marks edits by two teachers; offline queue replay after reconnect; connection-pool saturation across modules (ENG-6).

**11 Performance** — 2,000-student roster render; whole-school marks session; director cross-school dashboard; large report export; global search; parent fan-out at scale; sustained concurrent load on the single edge isolate.

**12 Human error** — clerk mis-types an amount/date (free-text date fields, audit XCT-3); wrong student selected; skips a required step; taps approve twice; uploads the wrong document.

---

## 3. Severity matrix

| Severity | Definition | Examples | Gate impact |
|---|---|---|---|
| **P0 — Critical** | Data loss, security breach, permission escalation, tenant-isolation failure, duplicate/lost financial transaction, broken auth/sync, critical crash, unrecoverable state | cross-tenant write; duplicate receipt; restore fails | **BLOCKS GA** (Constitution Part 7B automatic-failure) |
| **P1 — High** | Important workflow broken or unsafe under realistic conditions; data-integrity risk with a trigger; DR/backup gap | lost-update on concurrent collect; no off-site; alert not delivered | **BLOCKS GA** until fixed |
| **P2 — Medium** | Degraded/unsafe UX or performance; recoverable but harmful | stale-data shown as current; p95 over SLA; raw error leak | Fix before GA or owner-accept with plan |
| **P3 — Low** | Polish/robustness | cosmetic script warning; minor copy | Track; not GA-blocking |

---

## 4. Execution process

1. **Scope & freeze claims.** Confirm Phase-0 truth pass done; take the re-scoped claims as the baseline the Red Team attacks.
2. **Fan out by domain.** Independent operators/agents per domain (perspective-diverse — a security lens, a money lens, an ops lens, a UX lens). No operator sees another's angle until synthesis (multi-modal sweep).
3. **Attack on the live/staging stack**, read-only or rolled-back/isolated where possible; destructive tests on a throwaway tenant only.
4. **Adversarially verify every finding.** Each candidate finding is independently reproduced by a second operator prompted to *refute* it. Default to "refuted" unless reproduced. (Kills plausible-but-wrong findings.)
5. **Triage → severity → owner.** Assign severity via §3; route each confirmed finding to a Master-Roadmap Phase-5 fix task.
6. **Loop-until-dry.** Keep sweeping until two consecutive rounds surface nothing new.
7. **Report + gate.** Produce the report (§6); enforce the EOS gate (§5).

---

## 5. Evidence requirements & EOS gates

- **Evidence per finding (Constitution Part 7B — Evidence Requirements):** exact reproduction steps, `file:line` or live command + output/log, the crafted input, the observed vs expected result, severity, and blast radius. "Should be exploitable" is **not** evidence — reproduce it or drop it.
- **EOS gate (Part 7B — Automatic Failure Conditions):** any open **P0** ⇒ the Red Team verdict is **BLOCKED**; GA cannot proceed. Any open production-blocking **P1** ⇒ **BLOCKED**. Only when every P0 and blocking-P1 is fixed **and re-verified live** does the gate go **PASS**.
- **Certification rule:** the Red Team is certified complete only when (a) all 12 domains ran, (b) loop-until-dry converged, (c) every finding is adversarially verified, and (d) the fix wave (Phase 5) closed every P0/P1 with live re-verification. Record in the EOS run ledger.

---

## 6. Reporting templates

**6.1 Finding record**
```
RT-<domain>-<n> · <one-line title>
Domain: <1–12>   Severity: P0/P1/P2/P3   Status: Open/Fixed/Refuted
Reproduction: <steps / command>
Evidence: <log / output / file:line / crafted input>
Observed vs Expected: <…> vs <…>
Blast radius: <who/what/how many affected>
Root cause: <…>   Fix task: <Master-Roadmap P5-FIX-… id>
Verified-by (adversarial): <second operator> · Re-verified-live: yes/no
```

**6.2 Domain summary** — per domain: attacks run, findings by severity, converged? (Y/N), residual risk.

**6.3 Executive Red-Team report** — verdict (PASS/BLOCKED), P0/P1 counts, the "worst three" with blast radius, fixes required for GA, and a one-line confidence statement per domain.

**6.4 EOS ledger row** — date · scope (`Global Red Team`) · verdict · open P0/P1 · report path.

---

## 7. Relationship to the roadmap

- **Input:** the audit's confirmed + flagged risks (this framework seeds attacks from them so nothing is re-discovered from scratch).
- **Runs:** Master Roadmap **Phase 4** (`P4-RT-1`) after Phases 0–3.
- **Feeds:** **Phase 5** (`P5-FIX-1`) — every confirmed finding becomes a fix task, re-verified live.
- **Gates:** **Phase 6** (Pilot Sim) and **Phase 7** (Prod Cert) cannot begin until the Red Team verdict is PASS.

*A Red Team that starts from honest claims, verifies adversarially, and gates GA on live-re-verified fixes is how Akshara earns the right to call itself production-ready.*
