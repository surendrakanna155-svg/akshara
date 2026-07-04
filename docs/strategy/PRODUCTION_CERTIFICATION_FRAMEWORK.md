# Akshara ERP — Production Certification Framework

**Status:** Strategy / design-only (no code) · **Author:** Fable · **Date:** 2026-07-03
**Grounded in:** the Fable Final Audit (`docs/audits/`), the Engineering Constitution (Part 7B/8), and
`QA-R-012`. **Maps to:** Master Roadmap **Phase 7** (`P7-CERT-1`). **Passing = GA (General Availability).**

> **Purpose.** Define every gate Akshara must clear — with **real, live, committed evidence** — before it
> is declared production-ready for commercial rollout. The audit's core lesson governs this framework:
> **a certification is only as good as its evidence grade.** Nothing here passes on a local/contract/mock
> proof; every gate demands LIVE evidence or an explicit, owner-accepted exception.

---

## 1. Certification principle: the evidence-grade rule

Every gate item is graded by the strongest proof behind it (from the audit's taxonomy):

| Grade | Meaning | Accepted for GA? |
|---|---|---|
| **LIVE** | Proven on the live/production-equivalent stack (real auth/DB/RBAC), evidence committed | ✅ required for Critical gates |
| **LOCAL-LOGIC** | Proven by real logic in tests (money math, algorithms) | ✅ for non-live-dependent items |
| **CONTRACT** | Route/gate registration only (503-pattern) | ⚠ insufficient alone for a Critical gate |
| **RENDER-MOCK** | UI renders on mock data | ⚠ UX evidence only |
| **STAGED** | Authored, never run | ❌ not certifiable |

**Rule:** a Critical gate marked with anything below **LIVE** is **not passed** — it is an open item.

---

## 2. Certification gates (all must PASS)

### Gate T — Technical Readiness
| # | Requirement | Min grade | Audit link |
|---|---|---|---|
| T1 | `flutter analyze` 0 · full test suites green in CI **on the working branch** | LIVE (CI) | QA-3 |
| T2 | Backend + Flutter coverage floors enforced in CI; fresh lcov | LIVE (CI) | QA-8 |
| T3 | 41 untested routers have route/RBAC tests; per-route RBAC matrix complete | LOCAL+LIVE | QA-7 |
| T4 | Idempotency on **all** mutations; `row_version`/409 on money paths | LIVE | REL-1, ENG-1 |
| T5 | Draft-resume on all pilot-critical writes; outbox drains on restart | LIVE | REL-2/3/4 |
| T6 | No reachable backend-less/mock surface in the production build | LIVE | ENG-3 |
| T7 | Error envelopes standardized; no raw `error.message` leak; bulk arrays capped | LOCAL | ENG-7/8/9 |

### Gate S — Security
| # | Requirement | Min grade | Audit link |
|---|---|---|---|
| S1 | Auth: OTP server-verified; no backdoor; session revoke/logout **proven live** | LIVE | SEC-4 |
| S2 | Server-side RBAC on every route; escalation prevented; role→permission mapping verified live | LIVE | ENG-5, QA §3 |
| S3 | **Multi-tenant isolation proven live** — read+write, cross-tenant+cross-school+parent, under concurrency | LIVE | QA-2/LV-11 (extend concurrent) |
| S4 | Release hardening fail-closed; no debug-signing; no mock-auth in binary; PII encrypted at rest | LIVE | SEC-1/2/3/9 |
| S5 | Secrets in vault (no git credentials); TLS + cert pinning; edge uses `erp_tenant` not `service_role` | LIVE | DB-1/2, SEC-5 |
| S6 | Red Team verdict PASS (no open P0/blocking-P1) | LIVE | Phase 4/5 |

### Gate O — Operational
| # | Requirement | Min grade | Audit link |
|---|---|---|---|
| O1 | Automated encrypted backups running + **off-site** copy (3-2-1) | LIVE | LV-2 (done)/LV-3 |
| O2 | WAL/PITR → RPO ≤15 min (or owner-accepted RPO) | LIVE | LV-1 |
| O3 | **Restore drill green**, integrity == source, within RTO | LIVE | LV-8 (done) |
| O4 | Monitoring: health/alerts/jobs fire **and reach a human** | LIVE | LV-6 |
| O5 | Deployment runbook + rollback proven; single-runbook consolidated | LIVE | DOC-7 |
| O6 | Scale posture documented (registry/fleet/HA plan) for post-pilot growth | DOC | OPS-7 |

### Gate U — UX Readiness
| # | Requirement | Min grade | Audit link |
|---|---|---|---|
| U1 | Feedback layer (skeletons/refresh/haptics/success/freshness chip) shipped | RENDER+LIVE | UX-2/3 |
| U2 | Five daily-task flows meet the ergonomic targets (attendance/marks/approvals/fee/grading) | LIVE | UX-1 |
| U3 | Design-system enforced (lints, contrast in CI); accessibility pass (WCAG contrast, screen-reader) | LIVE (CI) | UX-4 + a11y |
| U4 | No dead buttons; no raw error enums reach the user; empty states actionable | LOCAL+LIVE | prior-audit |
| U5 | Parent-facing comms correct per-recipient language; English-first elsewhere | LIVE | comms |

### Gate A — AI Readiness
| # | Requirement | Min grade | Audit link |
|---|---|---|---|
| A1 | AI cost controls live: response cache, rate-limit, spend-cap, request timeout | LIVE | AI-1/2/3 |
| A2 | No-key health signal (no silent degradation); AI key provisioned | LIVE | AI-4 |
| A3 | Prompt-injection hardened; AI read-only, off all write/money paths; comms translation deterministic | LIVE | AI-5 |
| A4 | Every model call logged (surface, tokens, cost, cache-hit); per-tenant budget visible | LIVE | AI-1 |
| A5 | Determinism-first preserved (no fabricated numbers) | LOCAL+LIVE | AI arch |

### Gate P — Performance & Scalability
| # | Requirement | Min grade | Audit link |
|---|---|---|---|
| P1 | p95 latency meets `PERFORMANCE_TARGETS.md` T1–T8 at representative scale (live k6) | LIVE | QA-R-006 |
| P2 | Large rosters/marks/dashboards/reports/search within SLA | LIVE | ENG §3 |
| P3 | Concurrent multi-module load: no pool starvation; hot N+1 loops fixed | LIVE | ENG-6 |
| P4 | Multi-school concurrent operation with zero interference | LIVE | QA-R-002 |

### Gate B — Business & Commercial Readiness
| # | Requirement | Min grade | Audit link |
|---|---|---|---|
| B1 | Subscription/entitlement gating enforced live (`ENTITLEMENT_ENFORCEMENT=on`) | LIVE (done) | ENG-2/OPS-5 |
| B2 | Plan behaviour (feature gating, trial, upgrade/downgrade) certified; billing = Phase-2 per O6 (or promoted) | LIVE/OWNER | commercial |
| B3 | School branding GA-ready; white-label tiers = Phase-2 per O10 (or promoted) | LIVE/OWNER | white-label |
| B4 | Legal/compliance suite in place (privacy, children-data-consent, retention, terms) | DOC+LIVE | legal/ |
| B5 | Pricing, onboarding runbook, support process defined | DOC | ops |

### Gate D — Documentation & Governance
| # | Requirement | Min grade | Audit link |
|---|---|---|---|
| D1 | ProjectStatus + roadmaps match reality; over-claims re-scoped; tracker evidence-graded | DOC | DOC-1/3/4 |
| D2 | Every audit finding closed or dispositioned (see `AUDIT_FINDINGS_LEDGER.md`) | DOC | ledger |
| D3 | EOS run ledger complete; no open P0 across the project | LIVE | EOS |

---

## 3. The Final Production Checklist (`QA-R-012`)

GA may be declared only when **all** hold, each with committed LIVE evidence:

- [ ] All QA waves + Master-Roadmap Phases 0–6 complete.
- [ ] **No unresolved P0**; **no unresolved production-blocking P1**.
- [ ] Gates **T, S, O, U, A, P, B, D** all PASS at their required evidence grade.
- [ ] **Global Red Team** verdict PASS (Phase 4/5).
- [ ] **Pilot School Simulation** passed unattended, single + multi-school (Phase 6).
- [ ] **Tenant isolation** proven live under concurrency.
- [ ] **Security certification** passed (Gate S).
- [ ] **Performance targets** achieved at scale (Gate P).
- [ ] **Data reliability** verified live (Gate T4/T5).
- [ ] **Backup + off-site + tested restore** verified (Gate O1/O2/O3).
- [ ] **Live-regression cron 7 consecutive days green.**
- [ ] Documentation truthful; every finding dispositioned (Gate D).

---

## 4. Certification process

1. **Assemble evidence** per gate at its required grade; grade honestly (evidence-grade rule §1).
2. **Run the EOS** over each gate scope (`/eos <gate>`); each must return PASS.
3. **Independent sign-off:** a reviewer other than the implementer confirms the evidence supports the grade (no self-certification for Critical gates).
4. **Blockers:** any gate below its required grade = an open item → back to the relevant Master-Roadmap phase.
5. **Declare GA** only when the Final Checklist (§3) is fully satisfied; record the certification + evidence bundle; append the EOS ledger.
6. **Post-GA:** the live-regression cron + monitoring keep the certification honest; any red window re-opens the relevant gate.

---

## 5. Automatic-failure conditions (Constitution Part 7B)

Instant FAIL regardless of other scores: data loss · security breach · permission escalation · tenant-isolation failure · critical crash · **duplicate financial transaction** · broken auth/sync · critical regression · missing/failed backup verification · any production blocker. Any of these open ⇒ **BLOCKED**, GA cannot proceed.

---

## 6. Relationship to the roadmap & other frameworks

- **Entry:** Pilot School Simulation PASS (`PILOT_SCHOOL_SIMULATION_MASTER.md`, Phase 6) + Red Team PASS (`GLOBAL_RED_TEAM_FRAMEWORK.md`, Phase 4/5).
- **Runs:** Master Roadmap **Phase 7** (`P7-CERT-1`).
- **Output:** GA declaration + a committed evidence bundle that supersedes every local/contract/mock proof the audit flagged.
- **Standard:** one gate, one standard — the Engineering Constitution, executed by the EOS. This framework does not compete with it; it operationalizes `QA-R-012` with the audit's evidence-grade discipline.
