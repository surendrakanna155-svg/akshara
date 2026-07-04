# Akshara ERP — MASTER EXECUTION ROADMAP  (audit-phase consolidation)

> **⏭ SUPERSEDED (2026-07-03).** The **single authoritative roadmap** is now
> [`docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`](../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md)
> (Phases 0–8, full per-task fields, status flags, EOS gates), executed per
> [`docs/roadmap/AUTONOMOUS_EXECUTION_PLAN.md`](../roadmap/AUTONOMOUS_EXECUTION_PLAN.md) and journaled in
> [`docs/execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md). This document is
> retained as the audit-phase consolidation input (its Phases 0–7 map 1:1 into the final roadmap's Phases 0–8).

**Status:** 📄 Superseded — retained as audit-phase input to the final roadmap.
**Owner:** Fable Final Independent Audit consolidation · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Supersedes (as the forward plan):** `docs/audits/FABLE_FINAL_ROADMAP.md` (folded in) and the forward-looking
Phase B/C/D of `docs/FINAL_QA_ROADMAP.md` (which remains the frozen QA-wave history).
**Traceability:** every task cites the audit finding(s) it closes; the reverse map (every finding → one
task/disposition) is [`AUDIT_FINDINGS_LEDGER.md`](AUDIT_FINDINGS_LEDGER.md). **No finding is lost.**

> **Governance:** every wave is EOS-gated (`/eos <scope>` PASS against the Constitution) — nothing is
> "done" until it passes. Frozen owner decisions (O1–O10, identity freeze, attendance-auth) are
> respected. **Do not implement from this document yet** — it is the plan; execution begins on owner approval.

---

## 0. How to read this

- **Phases** are the owner-mandated structure (1–7), preceded by a **Phase 0 gate** that the audit proved
  must come first (truth + safety + live proof). Phase 0 is not optional — it de-risks everything after it.
- Each task: `ID · Category · Priority · Finding(s) closed · Dependency`.
- **Categories:** `CODE` · `UI/UX` · `INFRA` (DevOps) · `DOCS` · `TEST` · `SEC` · `AI` (Adaptive) · `PILOT` · `CERT`.
- **Priority:** **Critical** (blocks pilot/prod or data-safety) · **High** (needed for a real school) · **Medium** (productivity/quality) · **Low** (polish).

---

## 1. Phase map & critical path

```
 PHASE 0 — Foundation: Truth · Safety · Live Proof     [CRITICAL — gates all]
   truth pass → CI-on-branch → P0 safety fixes ∥ → scope-hide
        │
        ▼
 PHASE 1 — Remaining Roadmap Implementations           [HIGH]  ─┐
   reliability finish · identity finish · backend harden ·      │ (Phase 2 may
   HR/Hostel/Alumni/Finance module gaps · Phase-C waves ·       │  overlap late
   test coverage                                                │  Phase 1)
        │                                                       │
        ├───────────────► PHASE 2 — UI/UX Improvements  [HIGH] ◄┘
        │                   feedback pack · daily-task ergonomics ·
        │                   DS enforcement · accessibility
        │
        ├───────────────► PHASE 3 — Adaptive AI & Product Intelligence [MED]
        │                   AI cost foundation (first) → adaptive wave
        ▼
 PHASE 4 — Global /eos Red Team Audit                  [CRITICAL gate]
        ▼
 PHASE 5 — Fix every Red Team finding                  [CRITICAL]
        ▼
 PHASE 6 — Full Pilot School Simulation                [CRITICAL gate → PILOT-READY]
        ▼
 PHASE 7 — Production Certification                    [CRITICAL gate → GA]
```

**Optimal execution order (summary):** Phase 0 fully → then Phase 1 ∥ Phase 2 ∥ Phase 3-foundation in
parallel streams → Phase 3-adaptive → Phase 4 → Phase 5 → Phase 6 → Phase 7. Phases 4–7 are strictly
sequential gates. Phase 0 must finish before Phases 6–7 (and before Red Team is worth running).

---

## PHASE 0 — Foundation: Truth · Safety · Live Proof  [CRITICAL — gates everything]

*Rationale: the audit found the substance is strong but the claims, a few safety items, and the live
proof lag. Fix those first so every later phase (and the Red Team) rests on truth and a safe base.*

### 0.1 Documentation truth (`DOCS`)
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P0-DOC-1** Rewrite `ProjectStatus.md` to HEAD reality (modules shipped, QA local-complete, live-verified items) | High | DOC-1 | — |
| **P0-DOC-2** Commit/track the ~600-file doc cleanup + PROJECT_INDEX/README/CLAUDE | High | DOC-2 | — |
| **P0-DOC-3** Make this Master Roadmap the SSoT; point `FINAL_QA_ROADMAP` + `FABLE_FINAL_ROADMAP` at it | High | DOC-3 | — |
| **P0-DOC-4** Add tracker **evidence-grade column** (LIVE/LOCAL-LOGIC/CONTRACT/RENDER-MOCK/STAGED); re-scope over-claims (idempotency ~4%, row_version 1/4, "237 Verified", "certified") | High | DOC-4, QA-1 | — |
| **P0-DOC-5** Fix stale `TD-P0-01` + `AuditArchitecture` retention claims; consolidate the duplicate backup runbook | Med | DB-9/DOC-5, DB-6/DOC-6, DOC-7 | — |

### 0.2 Security release-discipline (`SEC`)
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P0-SEC-1** Release fail-closed guard — no prod build on dev-config; no debug-signing fallback | High | SEC-1, SEC-2 | — |
| **P0-SEC-2** Move PII session snapshot to encrypted secure storage | High | SEC-3 | — |
| **P0-SEC-3** Production-guard `ENABLE_DEMO_AUTH`; exclude mock/QA auth from the release binary (build flavor) | Med | SEC-9, SEC-10 | — |

### 0.3 Infrastructure / DR (`INFRA`)
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P0-INFRA-1** Off-site backup — set `RCLONE_REMOTE` + install `rclone` + nightly push (script is ready) | High | LV-3 | — |
| **P0-INFRA-2** WAL archiving / PITR (`archive_mode=on` + `archive_command`) → RPO ≤15 min | High | LV-1 | OWNER (RPO accept) |
| **P0-INFRA-3** Wire watchdog alert delivery (`ALERT_WEBHOOK_URL`/`ALERT_SMS_PHONES`) | Med | LV-6 | — |
| **P0-INFRA-4** Fix backup script `$1: unbound variable` warning | Low | LV-10 | — |
| **P0-INFRA-5** Rotate the hardcoded DB password out of the *migration* → vault (live already rotated; protect new provisioning) | Med | DB-1/OPS-6 | — |
| **P0-INFRA-6** Deploy-time assertion/self-test that edge connects as `erp_tenant` (not `service_role`) | High | DB-2 (harden) | — |

### 0.4 Money-safety code (`CODE`)
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P0-CODE-1** Wire the `finance_collections` `row_version`/409 check into collect + refund (money lost-update) | High | ENG-1 | — |
| **P0-CODE-2** Route-guard OFF the ~8 backend-less surfaces + hide thin peripherals for pilot | High | ENG-3/MOD-4 | OWNER (hide-list) |

### 0.5 Live proof / CI (`TEST`)
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P0-TEST-1** Stand up CI on the working branch (or gated branch); capture first green run IDs | High | QA-3 | — |
| **P0-TEST-2** Wire the 233-probe tenant-isolation suite into CI (regression for the now-live-proven QA-2) | High | QA-2, QA-7(part) | P0-TEST-1 |
| **P0-TEST-3** Start the live-regression cron; hold **7 consecutive days green** | High | QA-3 | P0-TEST-1 |

**Phase 0 exit (EOS gate):** no top-level doc contradicts code; no over-claim exceeds evidence; release builds fail-closed; off-site + WAL + alerts live; money row_version enforced; no mock surface reachable; CI green on the branch + cron clock started.

---

## PHASE 1 — Remaining Roadmap Implementations  [HIGH]

*The product-completion phase: finish the platforms whose seams the audit found unfinished, close the
module gaps, and execute the frozen enhancement backlog. Highly parallelizable by module (respect the
disjoint-file-ownership rule — no two implementation agents on the same module at once).*

### 1.1 Reliability platform finish (`CODE`)
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P1-CODE-1** Idempotency for **all** mutations (Dio interceptor mints key) · route marks "Save all" through `ReliableWriter` · drafts on marks+fee · boot/resume outbox flush · first-write `row_version` | High | REL-1,2,3,4,5 | P0 |
| **P1-CODE-2** Reliability polish — transactional dequeue · read-cache TTL · store-fallback telemetry · connectivity reachability + per-entity ordering | Med | REL-6,7,8,9 | P1-CODE-1 |

### 1.2 Backend hardening (`CODE`)
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P1-CODE-3** Stop raw `error.message` leakage (154 sites) · cap 4 unbounded bulk arrays · standardize error codes · 400→422 · route-registry lint · forced-auth choke wrapper · audit retention/partitioning implementation | Med | ENG-7/SEC-6, ENG-8/SEC-11, ENG-9, ENG-10, ENG-4, ENG-5, DB-6(code) | P0 |

### 1.3 Identity platform finish (`CODE`)
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P1-CODE-4** Change-phone flow (`PLAT-4`, makes the Identity-Permanence invariant true) · append-only ledger triggers · student 2-table integrity · admission# dedup audit · cross-tenant SECURITY DEFINER in-DB authz · remaining explicit `WITH CHECK` + ops-backup `FORCE` | High | DB-3, DB-5, DB-8, DB-7, DB-4/SEC-7, DB-10 | P0; OWNER (PLAT-0) |

### 1.4 Module gap closure (`CODE`)
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P1-CODE-5** HR payroll engine (salary structure + run/line-item generation; un-hide payroll) · fix hardcoded `employeeId` · employee-code uniqueness | High | MOD-2, MOD-3 | P0 |
| **P1-CODE-6** Cross-module Finance posting (library fines / hostel fees) — real posting or explicit out-of-Finance label | Med | MOD-1 | OWNER |
| **P1-CODE-7** Hostel — ship "residence-lite" (rooms/allocation/attendance) or build leave/gate-pass + billing | Med | MOD-6 | OWNER |
| **P1-CODE-8** Alumni — graduation auto-population + Finance link, or keep hidden | Low | MOD-5 | OWNER |

### 1.5 Product-enhancement waves (`CODE`) — the frozen backlog
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P1-PROD-0** XCT foundations (shared export pipeline, reminder rail, date pickers) | High | XCT-1/2/3 | P0 |
| **P1-PROD-1…21** Phase-C module/theme waves (C1–C21: Finance recovery CRM, Exams fast-marks/tabulation, Academic registers+certificates, Homework core, Transport fleet/fee, Inventory, Library, Communication, Principal/Director/Parent productivity) | High/Med | PRODUCT_ENHANCEMENT_BACKLOG | P1-PROD-0; OWNER (Appendix A) |

### 1.6 Security depth (`SEC`)
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P1-SEC-1** Session-revoke live-proof · TLS cert pinning · root/jailbreak detection + optional biometric app-lock | Med | SEC-4, SEC-5, SEC-8 | P0 |

### 1.7 Test coverage (`TEST`)
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P1-TEST-1** Real-device Patrol E2E · commit live-cert run artifacts · close 34 P0 + 23 P1 unverified rows · router tests for the 41 untested routers · regenerate lcov | High | QA-4,5,6,7,8 | P0-TEST |
| **P1-TEST-2** Concurrent-load test the single edge isolate + fix hot N+1 report loops | Med | ENG-6 | P1 |

### 1.8 Scale foundation (`INFRA`) — scheduled, not pilot-gating
| Task | Pri | Closes | Dep |
|---|---|---|---|
| **P1-INFRA-1** School Registry + migration-fleet-runner + read-replica/HA plan + PgBouncer + observability (Sentry/Prometheus) | Med | OPS-7, OPS-8 | OWNER (pre-scale, not pre-pilot) |

**Phase 1 exit:** platforms' seams finished; module gaps closed or explicitly hidden; backend hardened; test coverage real; enhancement waves EOS-passed.

---

## PHASE 2 — UI/UX Improvements  [HIGH]  (from the Fable + prior UX audit)

*The adoption phase — no re-architecture; ergonomic obsession on the five daily tasks + a feedback layer + design-system enforcement. May overlap the tail of Phase 1.*

| Task | Cat | Pri | Closes | Dep |
|---|---|---|---|---|
| **P2-UX-1** Tier 1 "feel & trust" pack — skeletons, pull-to-refresh, haptics, success views, offline **freshness chip**, copy/error-dictionary pass, draft-chip everywhere | UI/UX | High | UX-2, UX-3, prior-Tier-1 | P0 (draft infra) |
| **P2-UX-2** Tier 2 daily-task ergonomics — exception-grid attendance, inline marks/grading, generalized bulk-ops, cross-module **Approvals Inbox**, responsive `AksharaDataTable`, form-kit + keyboard/date sweep | UI/UX | High | UX-1, UX-5, prior-Tier-2 | P1-CODE-1 (marks) |
| **P2-UX-3** Tier 3 design-system enforcement — lints (no raw color/TextStyle), contrast checker in CI, persona-shell golden baselines | UI/UX | Med | UX-4, prior-Tier-3 | — |
| **P2-UX-4** Accessibility pass — WCAG contrast, screen-reader semantics, dynamic-type, tap-targets | UI/UX | Med | EOS gap | P2-UX-3 |
| **P2-UX-5** Dark-theme user toggle (already code-complete) | UI/UX | Low | UX-6 | — |

**Phase 2 exit:** rerun the prior audit's UX rubric → target ≥8/10.

---

## PHASE 3 — Adaptive AI & Product Intelligence  [MEDIUM]

*The owner's Adaptive-AI vision — but its cost/safety foundation is greenfield and must be built first.*

| Task | Cat | Pri | Closes | Dep |
|---|---|---|---|---|
| **P3-AI-1** AI **cost/safety foundation (build first)** — response/semantic cache · per-user/org rate-limit + spend-cap · request timeout → deterministic fallback · no-key health signal · prompt-injection hardening | AI/CODE | High | AI-1,2,3,4(res),5 | P0 |
| **P3-AI-2** Adaptive-AI wave — per-school adaptation (config/roles/lang/branding/history), proactive role-based dynamic dashboards, reuse-via-cache; rename "Intelligence"→"Analytics" where deterministic | AI | Med | Adaptive-AI vision, AI-6 | P3-AI-1; OWNER (timing) |

**Phase 3 exit:** AI has cost controls + a cache; adaptive behaviour is per-school and measured.

---

## PHASE 4 — Global /eos Red Team Audit  [CRITICAL gate]

| Task | Cat | Pri | Dep |
|---|---|---|---|
| **P4-RT-1** ONE adversarial, perspective-diverse red team on **honest, re-scoped claims** — security, data-integrity, multi-tenant isolation, money-correctness, abuse/cost, failure-injection, offline/sync | TEST/SEC | Critical | Phases 0–3 substantially complete |

**Why after Phase 0–3:** a red team is only as valuable as the claims it tests (Phase 0 truth) and the product it probes (Phases 1–3).

---

## PHASE 5 — Fix every Red Team finding  [CRITICAL]

| Task | Cat | Pri | Dep |
|---|---|---|---|
| **P5-FIX-1** Close every P4 finding; re-verify each live; re-run the relevant EOS category gates | CODE/SEC/INFRA | Critical | P4-RT-1 |

---

## PHASE 6 — Full Pilot School Simulation  [CRITICAL gate → PILOT-READY]

| Task | Cat | Pri | Dep |
|---|---|---|---|
| **P6-PILOT-1** Unattended single-school + 3-school-concurrent **live** pilot sim (real auth/DB/RBAC/gateway): onboarding → academic year → admissions → attendance → homework → exams → marks → report cards → fees → receipts → parent comms → transport → library → inventory → HR → principal → director. Confirm: money loop E2E, RLS isolation, DR drill, alerts firing, **no mock surface reachable**, AI cost controls active | PILOT | Critical | Phase 0 (safety) + Phase 1 (modules) + Phase 5 (fixes) |

**Phase 6 exit:** all stages green unattended; **declare PILOT-READY.**

---

## PHASE 7 — Production Certification  [CRITICAL gate → GA]

| Task | Cat | Pri | Dep |
|---|---|---|---|
| **P7-CERT-1** Full `QA-R-012` Final Production Checklist with **real evidence** · 7-consecutive-day live-regression green · commercial prerequisites decided (billing/quotas/white-label = Phase 2 per O6/O10, or promoted) · security + performance + DR + reliability certs re-affirmed live | CERT | Critical | P6-PILOT-1 |

**Phase 7 exit:** every checklist item satisfied with evidence; **declare PRODUCTION-CERTIFIED / GA.**

---

## 2. Category rollup (all tasks by discipline)

| Category | Tasks |
|---|---|
| **Code changes** | P0-CODE-1/2, P1-CODE-1…8, P1-PROD-0…21, P3-AI-1, P5-FIX-1 |
| **UI/UX** | P2-UX-1…5 |
| **Infrastructure / DevOps** | P0-INFRA-1…6, P1-INFRA-1 |
| **Documentation** | P0-DOC-1…5 |
| **Testing** | P0-TEST-1/2/3, P1-TEST-1/2, P4-RT-1 |
| **Security** | P0-SEC-1/2/3, P1-SEC-1 |
| **Adaptive AI** | P3-AI-1/2 |
| **Pilot Simulation** | P6-PILOT-1 |
| **Production Certification** | P7-CERT-1 |

## 3. Priority rollup

| Priority | Tasks |
|---|---|
| **Critical** | All of Phase 0; P4-RT-1; P5-FIX-1; P6-PILOT-1; P7-CERT-1 |
| **High** | P1-CODE-1/4/5, P1-PROD-0/1…, P1-TEST-1, P2-UX-1/2, P3-AI-1 |
| **Medium** | P1-CODE-2/3/6/7, P1-SEC-1, P1-TEST-2, P1-INFRA-1, P2-UX-3/4, P3-AI-2 |
| **Low** | P0-INFRA-4, P1-CODE-8, P2-UX-5 |

## 4. Key dependencies

- **Phase 0 gates Phases 6 & 7** (safety + proof before pilot/GA) and should precede Phase 4 (honest claims).
- **P1-CODE-1** (marks via ReliableWriter) is a dependency of **P2-UX-2** (marks-grid ergonomics).
- **P0-TEST-1** (CI on branch) gates P0-TEST-2/3 and the live-regression 7-day clock (which gates P7).
- **P3-AI-1** (AI cost foundation) gates **P3-AI-2** (adaptive wave).
- **Owner decisions** gate: P0-CODE-2 (hide-list), P0-INFRA-2 (RPO), P1-CODE-4 (PLAT-0), P1-CODE-6/7/8 (module scope), P1-INFRA-1 (scale timing), P1-PROD-* (Appendix A), P3-AI-2 (timing).

## 5. Owner decisions to unblock the plan (batch these)

1. Open the **hide-list** for P0-CODE-2 (the 8 backend-less surfaces + Alumni + Hostel billing/leave + HR payroll).
2. **DR RPO** — tighten to ≤15 min (WAL) or accept ~24h for pilot (P0-INFRA-2).
3. **Module scope** — Hostel residence-lite vs full; Alumni auto-populate vs hide; library/hostel Finance posting real vs labelled (P1-CODE-6/7/8).
4. **Appendix A (~26 items)** defaults so the blocked P1-PROD waves can schedule.
5. **PLAT-0** non-student Public-ID scheme (P1-CODE-4).
6. **Adaptive-AI timing** and **Consolidation wave** go/no-go (P3-AI-2, DOC-8).
7. `APP_ENV=staging` intent + shared-box strategy (LV-5, LV-4).

---

*This is the authoritative implementation plan. It consolidates reports 00–11 + the frozen backlogs,
merges duplicates, excludes items already fixed during the audit, and loses no finding (see
[`AUDIT_FINDINGS_LEDGER.md`](AUDIT_FINDINGS_LEDGER.md)). Execution begins only on owner approval, wave by
wave, each gated by `/eos`.*
